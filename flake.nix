{
  description = "OpenRouter API Key Provisioner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      packages =
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
          (
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
              server = pkgs.writers.writePython3Bin "openrouter-provisioner" {
                libraries = [ ];
              } builtins.readFile ./openrouter.py;
            in
            {
              inherit server;
              default = server;
            }
          );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.openrouter-provisioner;
        in
        {
          options.services.openrouter-provisioner = {
            enable = lib.mkEnableOption "OpenRouter API Key Provisioner";

            keyFile = lib.mkOption {
              type = lib.types.path;
              description = "Path to a file containing the OpenRouter provisioning key";
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
                  OPENROUTER_PROVISIONING_KEY=$(cat $CREDENTIALS_DIRECTORY/key)
                  export OPENROUTER_PROVISIONING_KEY
                  exec ${self.packages.${pkgs.system}.server}/bin/openrouter-provisioner
                ''}";
                Restart = "on-failure";
              };
            };
          };
        };
    };
}
