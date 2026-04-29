{
  description = "PSKC Astro site development and LAN preview environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
            inherit system;
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, system }:
        {
          pskc-lan-preview = pkgs.writeShellApplication {
            name = "pskc-lan-preview";
            runtimeInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gawk
              pkgs.gnugrep
              pkgs.gnused
              pkgs.iproute2
              pkgs.nginx
              pkgs.nodejs_24
            ];
            text = builtins.readFile ./nix/pskc-lan-preview.sh;
          };

          default = self.packages.${system}.pskc-lan-preview;
        }
      );

      apps = forAllSystems (
        { system, ... }:
        {
          pskc-lan-preview = {
            type = "app";
            program = "${self.packages.${system}.pskc-lan-preview}/bin/pskc-lan-preview";
          };

          default = self.apps.${system}.pskc-lan-preview;
        }
      );

      devShells = forAllSystems (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.iproute2
              pkgs.nginx
              pkgs.nodejs_24
              self.packages.${system}.pskc-lan-preview
            ];

            shellHook = ''
              preview_port="''${PSKC_PORT:-8080}"
              preview_auto="''${PSKC_AUTO_PREVIEW:-1}"

              echo "PSKC Astro shell"
              echo "  npm run dev          # Astro dev server"
              echo "  npm run build        # Build static dist/"
              echo "  pskc-lan-preview     # Foreground nginx preview"
              echo "  pskc-lan-preview --stop"
              echo

              if [ "$preview_auto" = "1" ]; then
                echo "PSKC LAN preview auto-start"
                echo "  Serving existing dist/ on port $preview_port"
                PSKC_BUILD="''${PSKC_AUTO_BUILD:-0}" pskc-lan-preview --daemon || {
                  echo "  Preview did not start. Run npm run build, then pskc-lan-preview --daemon."
                }
              else
                echo "PSKC LAN preview"
                echo "  Auto-start disabled by PSKC_AUTO_PREVIEW=0"
                echo "  Start:  pskc-lan-preview --daemon"
                echo "  Local:  http://127.0.0.1:$preview_port/"
              fi
            '';
          };
        }
      );
    };
}
