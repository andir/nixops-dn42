{ params, ...}:
{ lib, ...}:
with lib;
let
    wireguardInterfaces = (mapAttrs (x: v: {
       listenPort = v.listenPort;
       privateKey = v.privateKey;
       allowedIPsAsRoutes = false;
       peers = [
       (
          (if (builtins.hasAttr "endpoint" v) then { endpoint = v.endpoint; }
           else {})
	//
	  {
            allowedIPs = ["0.0.0.0/0" "::/0"];
            publicKey = v.publicKey;
           }
       )
       ];
     }) params);
     wireguardPorts = lib.attrValues (lib.mapAttrs (key: value: value.listenPort) params);
     wireguardNetworks = lib.mapAttrs' (key: value: lib.nameValuePair ("10-" + key) ({
       name = key;
       address = value.ips;
    })) params;
in
{

  networking.firewall.allowedUDPPorts = wireguardPorts;
  networking.wireguard.interfaces = wireguardInterfaces;
  systemd.network.networks = wireguardNetworks;
}
