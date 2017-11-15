{
   network.description = "boolean.h4ck.space";
   boolean = { config, fetchpatch, lib, pkgs, ... }:
   let
     params = import ./params.nix;
     importModule = file: args: let
       f = import file;
       in f args;
#     dn42 = importModule ./modules/dn42.nix { lib = lib; params = (import ./dn42.nix); };
   in
   {
      imports = [
      	(importModule ./modules/wireguard.nix { params = params.wireguard; })
        ./dn42.nix
        ./modules/dn42.nix
 #       (importModule ./modules/wireguard.nix { params = dn42.wireguardConfig; })
        (importModule ./modules/cache.nix { params = params.cache; })
        (importModule ./modules/babel.nix { params = params.babel; })
      ];

      nix.binaryCaches = [ "https://cache.nix.h4ck.space/" "http://cache.nixos.org/" ];

      environment.systemPackages = with pkgs; [ tcpdump vim ];

      boot.tmpOnTmpfs = true;

      time.timeZone = "Europe/Berlin";
      networking = {
      	useNetworkd = true;
        firewall.allowedTCPPorts = [
          # 22 # ssh (is implicit)
        ];
      };

      # disable networkd-wait-online.target since that blocks execution and takes forever..
      systemd.services = {
	      systemd-networkd-wait-online.enable = false;
      };

      # OpenSSH Server
      services.openssh.enable = true;
      users.users."root".openssh.authorizedKeys.keys = params.sshKeys;
   };
}
