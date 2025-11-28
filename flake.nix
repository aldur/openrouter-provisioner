{
  description = "OpenRouter API Key Provisioner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        server = pkgs.stdenv.mkDerivation {
          pname = "openrouter-provisioner-server";
          version = "0.1.0";
          src = ./.;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/bin
            cp openrouter.py $out/bin/openrouter-provisioner
            chmod +x $out/bin/openrouter-provisioner
          '';
        };

        client = pkgs.stdenv.mkDerivation {
          pname = "openrouter-provisioner-client";
          version = "0.1.0";
          src = ./.;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/bin
            cp client.sh $out/bin/openrouter-client
            chmod +x $out/bin/openrouter-client
            substituteInPlace $out/bin/openrouter-client \
              --replace 'curl' '${pkgs.curl}/bin/curl' \
              --replace 'jq' '${pkgs.jq}/bin/jq'
          '';
        };

        default = self.packages.${system}.server;
      }
    );

    nixosModules.default = { config, lib, pkgs, ... }:
      let
        cfg = config.services.openrouter-provisioner;
      in {
        options.services.openrouter-provisioner = {
          enable = lib.mkEnableOption "OpenRouter API Key Provisioner";

          keyFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to file containing the OpenRouter provisioning key";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8000;
          };
        };

        config = lib.mkIf cfg.enable {
          systemd.services.openrouter-provisioner = {
            description = "OpenRouter API Key Provisioner";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];

            serviceConfig = {
              Type = "simple";
              DynamicUser = true;
              LoadCredential = "key:${cfg.keyFile}";
              ExecStart = "${pkgs.writeShellScript "openrouter-start" ''
                export OPENROUTER_PROVISIONING_KEY=$(cat $CREDENTIALS_DIRECTORY/key)
                exec ${self.packages.${pkgs.system}.server}/bin/openrouter-provisioner
              ''}";
              Restart = "on-failure";
            };
          };
        };
      };
  };
}
