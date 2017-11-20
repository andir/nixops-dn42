{ config, pkgs, lib, ... }:
let
  wireguardKeyType = with lib; types.addCheck types.str (v: (stringLength v) > 40);
  cfg = config.dn42;
in
with lib;
{

  options = {
    dn42 = {
      enable = mkEnableOption "enable dn42 configuration";

      table = mkOption {
        type = types.ints.unsigned;
        default = 42;
      };

      bgp = mkOption {
        type = types.submodule {
          options = {
            asn = mkOption { type = types.ints.unsigned; };
            routerId = mkOption { type = types.str; };
            staticRoutes = mkOption {
              type = types.submodule {
                options = {
                  ipv4 = mkOption { type = types.listOf types.str; default = []; };
                  ipv6 = mkOption { type = types.listOf types.str; default = []; };
                };
              };
            };
          };
        };
      };

      peers = mkOption {
        type = (types.attrsOf(types.submodule {
          options = {
            tunnelType = mkOption {
              type = types.enum ["wireguard"];
              description = "tunnel technology used";
            };
            mtu = mkOption {
              type = types.ints.unsigned;
              description = "mtu on the interface";
            };
            wireguardConfig = mkOption {
              type = types.submodule {
                options = {
                  localPort = mkOption { type = types.ints.unsigned; };
                  endpoint = mkOption { type = types.str; };
                  publicKey = mkOption { type = wireguardKeyType; };
                  privateKey = mkOption { type = wireguardKeyType; };
                };
              };
            };
            bgp = mkOption {
              type = types.submodule {
                options = {
                  asn = mkOption { type = types.ints.unsigned; };
                  local_pref = mkOption { type = types.ints.unsigned; };
                  export_med = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
                  export_prepend = mkOption { type = types.ints.unsgined; default = 0; };
                  import_prepend = mkOption { type = types.ints.unsigned; default = 0; };
                  import_reject = mkOption { type = types.bool; default = false; };
                  export_reject = mkOption { type = types.bool; default = false; };
                };
              };
            };
            addresses = mkOption {
              type = types.submodule {
                options = {
                  ipv6 = mkOption {
                    default = null;
                    type = types.nullOr (types.submodule {
                      options = {
                        local_address = mkOption { type = types.str; };
                        remote_address = mkOption { type = types.str; };
                        cidr = mkOption { type = types.ints.unsigned; };
                      };
                    });
                  };
                  ipv4 = mkOption {
                    default = null;
                    type = types.nullOr (types.submodule {
                      options = {
                        local_address = mkOption { type = types.str; };
                        remote_address = mkOption { type = types.str; };
                        cidr = mkOption { type = types.ints.unsigned; };
                      };
                    });
                  };
                };
              };
            };
          };
        }));
      } // {
        check = v: (if v.tunnelType == "wireguard" then hasAttr "wireguardConfig" v else true);
      };
    };
  };

  config = let
    wireguardPeers = filterAttrs (n: v: v.tunnelType == "wireguard") cfg.peers;
    wireguardInterfaces = (mapAttrs (peerName: peer: {
       listenPort = peer.wireguardConfig.localPort;
       privateKey = peer.wireguardConfig.privateKey;
       allowedIPsAsRoutes = false;
       table = cfg.table;
       peers = [
       (
          (if (builtins.hasAttr "endpoint" peer.wireguardConfig) then { endpoint = peer.wireguardConfig.endpoint; }
           else {})
        //
          {
            allowedIPs = ["0.0.0.0/0" "::/0"];
            publicKey = peer.wireguardConfig.publicKey;
           }
       )
       ];

    }) wireguardPeers);
    wireguardPorts = lib.attrValues (lib.mapAttrs (peerName: peer:  peer.listenPort) wireguardInterfaces);
    wireguardNetworks = lib.mapAttrs' (peerName: peer: lib.nameValuePair ("42-" + peerName) ({
      name = peerName;
      DHCP = "none";
      addresses = let
        addrs =
          lib.optional (peer.addresses.ipv6 != null) ({ addressConfig = ({ Address = "${peer.addresses.ipv6.local_address}/${toString peer.addresses.ipv6.cidr}"; }
                                                      // (if peer.addresses.ipv6.cidr == 128 then { Peer = "${peer.addresses.ipv6.remote_address}/128"; } else {})); })
          ++
          lib.optional (peer.addresses.ipv4 != null) ({ addressConfig = ({ Address = "${peer.addresses.ipv4.local_address}/${toString peer.addresses.ipv4.cidr}"; }
                                                      // (if peer.addresses.ipv4.cidr == 32 then { Peer = "${peer.addresses.ipv4.remote_address}/32"; } else {})); })
        ;
      in addrs;
    })) wireguardPeers;

    birdPeers = {
      ipv4 =  filterAttrs (n: v: hasAttr "bgp" v && v.addresses.ipv4 != null) cfg.peers;
      ipv6 = filterAttrs (n: v: hasAttr "bgp" v && v.addresses.ipv6 != null) cfg.peers;
    };

    # determine if we should enable bird and bird6
    enableBird6 = (builtins.any (x: true) (builtins.attrValues birdPeers.ipv6)) == true;
    enableBird4 = (builtins.any (x: true) (builtins.attrValues birdPeers.ipv4)) == true;

    # common bird configuration
    commonBirdConfig = if (enableBird4 || enableBird6) then ''
      router id ${cfg.bgp.routerId};
      define MY_ASN = ${toString cfg.bgp.asn};

      protocol device {
        scan time 60;
      };

      protocol direct d_dn42 {
        interface "dn42_*";
      }

      table dn42;

      protocol kernel k_dn42 {

        table dn42;
        kernel table ${toString cfg.table};
        import all;
        export all;
        persist;
      }

      function is_static_announce ()
      {
        if proto ~ "s_announce" then return true;
        return false;
      }

      template bgp base_bgp {
        local as ${toString cfg.bgp.asn};
        import keep filtered;
        graceful restart on;
        graceful restart time 120;
        interpret communities yes;
        enable extended messages off;
        med metric on;
      }

      template bgp dn42_peer from base_bgp {
        table dn42;
        next hop self;
        export filter {
          if is_static_announce() then accept;
          reject;
        };
      }
    '' else "";

    mkPeerConfig = family: name: peer: let
      remote_address = peer.addresses.${family}.remote_address;
    in ''
      protocol bgp dn42_${name} from dn42_peer {
        neighbor ${remote_address}${if hasPrefix "fe80:" remote_address then "%${name}" else ""} as ${toString peer.bgp.asn};
        import filter {
          bgp_local_pref = ${toString peer.bgp.local_pref};
          ${
            if peer.bgp.import_prepend != 0 then
              concatStrings (map (x: "bgp_path.prepend(MY_ASN);\n") (range 0 peer.bgp.import_prepend))
            else ""
          }

          ${if peer.bgp.import_reject then "reject" else "accept"};
        };
      }
    '';

    mkBirdConfig = version: let
      peers = birdPeers.${version};
      routes = cfg.bgp.staticRoutes.${version};
    in ''
      ${commonBirdConfig}
      protocol static s_announce {
        table dn42;
        ${concatStringsSep "\n" (map (n: "route ${n} blackhole;") routes)}
      }
      ${concatStrings
        (mapAttrsToList (mkPeerConfig version) peers)
      }
    '';

    mkFirewallRules = version: let
      peers = birdPeers.${version};
      prefix = if version == "ipv4" then "ip" else "ip6";
      mkPeerFirewall = name: peer: ''
        ${prefix}tables -A nixos-fw -i ${name} -p tcp -s ${peer.addresses.${version}.remote_address}  --dport 179 -j ACCEPT
        ${
          concatStringsSep "\n" (mapAttrsToList (p: v: if p != name then "${prefix}tables -A FORWARD -i ${name} -o ${p} -j ACCEPT" else "") peers)
        }
      '';
    in (concatStrings (mapAttrsToList (mkPeerFirewall) peers));

    wireguardAfterResolved = mapAttrs' (name: value: nameValuePair ("wireguard-" + name) ({
      after = [ "nss-lookup.target" "network-online.target" ];
    })) wireguardPeers;


  in lib.mkIf cfg.enable {
    networking.wireguard.interfaces = wireguardInterfaces;
    networking.firewall.allowedUDPPorts = wireguardPorts;
    networking.firewall.extraCommands = concatStringsSep "\n" ([]
      ++ (optional (enableBird4) (mkFirewallRules "ipv4"))
      ++ (optional (enableBird6) (mkFirewallRules "ipv6"))
      ++ ["ip46tables -A FORWARD -j DROP"]
    );

    systemd.network.networks = wireguardNetworks;

    services.bird.enable = mkDefault enableBird4;
    services.bird6.enable = mkDefault enableBird6;

    services.bird.config = mkIf enableBird4 (mkBirdConfig "ipv4");
    services.bird6.config = mkIf enableBird6 (mkBirdConfig "ipv6");

    systemd.services = {
      "dn42-policy-routing" = {
        enable = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "networking.target" ];
        script = ''
          ${pkgs.iproute}/bin/ip rule add from 172.16.0.0/12 lookup ${toString cfg.table}
          ${pkgs.iproute}/bin/ip rule add to 172.16.0.0/12 lookup ${toString cfg.table}
        '';

        preStop = ''
          ${pkgs.iproute}/bin/ip rule del from 172.16.0.0/12 lookup ${toString cfg.table}
          ${pkgs.iproute}/bin/ip rule del to 172.16.0.0/12 lookup ${toString cfg.table}
        '';
      };
    } // wireguardAfterResolved;
  };
}
