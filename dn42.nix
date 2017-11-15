{ config, ... }:
let
  secrets = import ./secrets.nix;
in
{
  config.dn42 = {
          enable = true;
          bgp = {
            asn = 4242423991;
            routerId = "172.22.248.18";
            staticRoutes = {
              ipv4 = [
                "172.20.199.0/24"
                "172.20.24.0/23"
                "172.20.255.0/24" # transfer networks
              ];
              ipv6 = [
                "fd21:a07e:735e::/48"
                "fd42:4242:4200::/40"
              ];
            };
          };

          peers = {
            cccda = {
              tunnelType = "wireguard";
              mtu = 1400;
              wireguardConfig = {
                localPort = 51001;
                endpoint = "core1.darmstadt.ccc.de:43011";
                publicKey = "iB8P2uuKGISflakJiHMGuBR7zKK44qx+ioqeBN0sEnk=";
                privateKey = secrets.keys.cccda;
              };
              bgp = {
                asn = 4242420101;
                local_pref = 100;
              };
              addresses = {
                ipv4 = {
                        local_address = "172.22.248.18";
                        remote_address = "172.22.248.17";
                        cidr = 30;
                };
                ipv6 = {
                        local_address = "fe80::f00";
                        remote_address = "fe80::ccc:da";
                        cidr = 64;
                };
              };
            };
            floklidijkstra = {
              tunnelType = "wireguard";
              mtu = 1400;
              wireguardConfig = {
                localPort = 51002;
                endpoint = "dijkstra.robo6.io:51823";
                publicKey = "A5GoTB2lr7pY9G0gMY0CxgGPSJc19YHwPNA1yVH7bjw=";
                privateKey = secrets.keys.floklidijkstra;
              };
              bgp = {
                asn = 4242422100;
                local_pref = 90;
              };
              addresses = {
                ipv4 = {
                      local_address = "172.20.42.123";
                      remote_address = "172.20.42.122";
                      cidr = 30;
                };
                ipv6 = {
                      local_address = "fe80::f00";
                      remote_address = "fe80::cafe:babe";
                      cidr = 64;
                };
              };
            };

            mic92n1 = {
              tunnelType = "wireguard";
              mtu = 1400;
              wireguardConfig = {
                localPort = 51003;
                endpoint = "dn42.thalheim.io:4246";
                publicKey = "fxiGmHUK1aMa07cejTP3SHxYivIj3aXZwdvzTEXmYHM=";
                privateKey = secrets.keys.mic92n1;
              };
              bgp = {
                asn = 4242420092;
                local_pref = 100;
              };
              addresses = {
                ipv4 = {
                  local_address = "172.20.25.102";
                  remote_address = "172.23.75.1";
                  cidr = 32;
                };
                ipv6 = {
                  local_address = "fe80::f00";
                  remote_address = "fe80::92";
                  cidr = 128;
                };
              };
            };
          };
  };
}
