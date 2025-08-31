{
  description = "Sandmap (nmap front-end) packaged as a Nix flake";

  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeDeps = with pkgs; [
            bash
            coreutils
            gawk
            gnugrep
            gnused
            gnutar
            gzip
            nmap
            xterm
            proxychains
          ];
        in {
          default = pkgs.stdenv.mkDerivation {
            pname = "sandmap";
            version = "1.2.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper pkgs.installShellFiles ];

            # No build system; just install files into the expected layout
            installPhase = ''
              runHook preInstall

              mkdir -p "$out/bin"
              mkdir -p "$out/src" "$out/lib" "$out/etc" "$out/data" "$out/static" "$out/templates"

              install -m0755 bin/sandmap "$out/bin/sandmap"
              cp -r src/* "$out/src/"
              cp -r lib/* "$out/lib/"
              cp -r etc/* "$out/etc/"
              cp -r data/* "$out/data/"
              cp -r static/* "$out/static/"
              cp -r templates/* "$out/templates/"

              # Normalize shebangs
              patchShebangs "$out/bin" "$out/lib" "$out/src"

              # Wrap with runtime PATH for required tools
              wrapProgram "$out/bin/sandmap" \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

              # Provide a basic manpage if present (not required)
              if [ -f man/sandmap.8 ]; then
                install -D -m0644 man/sandmap.8 "$out/share/man/man8/sandmap.8"
              fi

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Tool supporting network/system recon via Nmap engine";
              homepage = "https://github.com/trimstray/sandmap";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
              mainProgram = "sandmap";
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sandmap";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.bashInteractive
              pkgs.nmap
              pkgs.xterm
              pkgs.proxychains
              pkgs.gawk
            ];
          };
        });
    };
}

