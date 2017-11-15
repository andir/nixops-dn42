{ params }:
{ pkgs, lib, ... }:
with lib;
let
  mkRedist = {net, le, metric, deny ? false}: ''
    redistribute ip ${net} le ${le} ${if deny then "deny" else ""} 
  '';

  routes = [{
    net = "172.16.0.0/12";
    le = "32";
    metric = 100;
  }];

  config  = concatStringsSep "\n" (
    (map (entry: mkRedist entry) routes) ++ [
      "redistribute local ip 172.16.0.0/12 le 32 allow"
#      "redistribute local deny"
      "redistribute deny"
      "in ip 0.0.0.0/0 le 0 deny"
      "in ip ::/0 le 0 deny"
    ]
  );

  interfaces = foldl' (a: b: a // b) {} (map (name: { 
    ${name} = { type = "tunnel"; };
  }) params.interfaces);
in
{
  config.services.babeld = {
    enable = true;
    interfaces = {
      # static config here
    } // interfaces;
    extraConfig = config;
  };
  config.networking.firewall.extraCommands = concatStringsSep "\n" (
    (map (interface: "ip46tables -A nixos-fw -i ${interface} -p udp --dport 6696 -j ACCEPT -m comment --comment babel") params.interfaces)
  );

}
