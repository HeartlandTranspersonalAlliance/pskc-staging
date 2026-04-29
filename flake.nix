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
              preview_host="''${PSKC_HOST:-0.0.0.0}"
              preview_port="''${PSKC_PORT:-8080}"

              echo "PSKC Astro shell"
              echo "  npm run dev          # Astro dev server"
              echo "  npm run build        # Build static dist/"
              echo "  pskc-lan-preview     # Build and serve dist/ over LAN with nginx"
              echo
              echo "PSKC LAN preview"
              echo "  Start:  pskc-lan-preview"
              echo "  Local:  http://127.0.0.1:$preview_port/"
              echo "  Listen: http://$preview_host:$preview_port/"

              if command -v ip >/dev/null 2>&1; then
                preview_addresses="$(
                  ip -o -4 addr show scope global 2>/dev/null |
                    awk '{ split($4, address, "/"); print address[1] }' || true
                )"

                while read -r preview_address; do
                  if [ -n "$preview_address" ]; then
                    echo "  LAN:    http://$preview_address:$preview_port/"
                  fi
                done <<< "$preview_addresses"
              fi

              echo "  Port:   PSKC_PORT=$preview_port"
            '';
          };
        }
      );
    };
}
