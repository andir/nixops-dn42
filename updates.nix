{ pkgs, lib, ... }:
with lib;
let
  pkg = with rustPlatform;
    buildRustPackage rec {
      src = fetchFromGitHub {
        owner = "andir";
        repo = "nix-update-tracker";
        sha256 = "0k5vkn112bjwh4wnxryzqz79dlja64k7s105mf3yaik136hqnmqv";
      };
      cargoSha256 = "03bqhgz8c4ipdkd3g448bcrr6d188h87vskcfcc3mqlcxg77b8q5";
      buildInputs = [ pkgs.openssl ];
    };
in {

  systemd.services."nix-updates" = {
    serviceConfig = {
      ExecStart = let
        script = ''
      in
      "${script}";
    };
  };

}
