{ params, ...}:
{ lib, pkgs, ...}:
with lib;
let
  vhost = params.hostname;
  cacheDir = "/var/cache/nix";
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  systemd.services."contains@cache".enable = true;
  containers."cache" = {
    config = {
      environment.systemPackages = with pkgs; [ ltrace ];
      systemd.services.nginx = {
        serviceConfig = {
#          WorkingDirectory = cacheDir;
#          ReadWriteDirectories = "${cacheDir} /var/spool/nginx/logs";
#          AmbientCapabilities = "cap_net_bind_service";
#          CapabilityBoundingSet = "cap_net_bind_service";
#          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
#          ProtectSystem = "full";
        };
	preStart = ''
          if ! [ -d ${cacheDir} ]; then
            mkdir -p ${cacheDir}
            chown -R nginx:nginx ${cacheDir}
          fi
        '';
      };
      services.nginx = {
        enable = true;
        resolver.addresses = [ params.resolver ];
        appendHttpConfig = ''
        proxy_cache_path ${cacheDir} levels=1:2 keys_zone=cachecache:100m max_size=${params.maxSize} inactive=${params.maxTTL} use_temp_path=off;


        # status code mapping to only cache sucess
        map $status $cache_header {
          200 "public";
          302 "public";
          default "no-cache";
        }
        access_log logs/access.log;
        '';
        virtualHosts."${vhost}" = {
          enableACME = true;
          forceSSL = true;

          # pseudo target for upstream proxy
          locations."@fallback" = {
            proxyPass = "${params.upstream}";
            extraConfig = ''
              proxy_cache cachecache;
              proxy_cache_valid 200 302 ${params.cacheTTL};
              expires max;
              add_header Cache-Control $cache_header always;
            '';
          };

          # default target (/)
          locations."/" = {
            root = "/var/public-nix-cache";
            extraConfig = ''
              expires max;
              add_header Cache-Control $cache_header always;
              # redirect 404's to upstream, fetches from upstream if cache miss
              error_page 404 = @fallback;
	    '';
          };

          # /nix-cache-info will only be cached ${params.indexCacheTTL}
          locations."/nix-cache-info" = {
            proxyPass = "${params.upstream}";
            extraConfig = ''
              proxy_cache cachecache;
              proxy_cache_valid 200 302 ${params.cacheTTL};
              expires max;
              add_header Cache-Control $cache_header always;
            '';
          };

        };
      };
    };
  };

}
