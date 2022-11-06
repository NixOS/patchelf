{
  description = "A tool for modifying ELF executables and libraries";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:

    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      patchelfFor = pkgs: pkgs.callPackage ./patchelf.nix {
        inherit version;
        src = self;
      };
    in

    {
      overlays.default = final: prev: {
        patchelf-new-musl = patchelfFor final.pkgsMusl;
        patchelf-new = patchelfFor final;
      };

      hydraJobs = {
        tarball =
          pkgs.releaseTools.sourceTarball rec {
            name = "patchelf-tarball";
            inherit version;
            versionSuffix = ""; # obsolete
            src = self;
            preAutoconf = "echo ${version} > version";
            postDist = ''
              cp README.md $out/
              echo "doc readme $out/README.md" >> $out/nix-support/hydra-build-products
            '';
          };

        coverage =
          (pkgs.releaseTools.coverageAnalysis {
            name = "patchelf-coverage";
            src = self.hydraJobs.tarball;
            lcovFilter = ["*/tests/*"];
          }).overrideAttrs (old: {
            preCheck = ''
              # coverage cflag breaks this target
              NIX_CFLAGS_COMPILE=''${NIX_CFLAGS_COMPILE//--coverage} make -C tests phdr-corruption.so
            '';
          });

        build = forAllSystems (system: self.packages.${system}.patchelf);
        build-sanitized = forAllSystems (system: self.packages.${system}.patchelf.overrideAttrs (old: {
          configureFlags = [ "--with-asan " "--with-ubsan" ];
          # -Wno-unused-command-line-argument is for clang, which does not like
          # our cc wrapper arguments
          CFLAGS = "-Werror -Wno-unused-command-line-argument";
        }));

        # x86_64-linux seems to be only working clangStdenv at the moment
        build-sanitized-clang = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: self.hydraJobs.build-sanitized.${system}.override {
          stdenv = nixpkgs.legacyPackages.${system}.llvmPackages_latest.libcxxStdenv;
        });

        release = pkgs.releaseTools.aggregate
          { name = "patchelf-${self.hydraJobs.tarball.version}";
            constituents =
              [ self.hydraJobs.tarball
                self.hydraJobs.build.x86_64-linux
                self.hydraJobs.build.i686-linux
                # FIXME: add aarch64 emulation to our github action...
                #self.hydraJobs.build.aarch64-linux
                self.hydraJobs.build-sanitized.x86_64-linux
                #self.hydraJobs.build-sanitized.aarch64-linux
                self.hydraJobs.build-sanitized.i686-linux
                self.hydraJobs.build-sanitized-clang.x86_64-linux
              ];
            meta.description = "Release-critical builds";
          };

      };

      checks = forAllSystems (system: {
        build = self.hydraJobs.build.${system};
      });

      devShells = forAllSystems (system: {
        glibc = self.packages.${system}.patchelf;
        default = self.devShells.${system}.glibc;
      } // nixpkgs.lib.optionalAttrs (system != "i686-linux") {
        musl = self.packages.${system}.patchelf-musl;
      });

      packages = forAllSystems (system: {
        patchelf = patchelfFor nixpkgs.legacyPackages.${system};
        default = self.packages.${system}.patchelf;
      } // nixpkgs.lib.optionalAttrs (system != "i686-linux") {
        patchelf-musl = patchelfFor nixpkgs.legacyPackages.${system}.pkgsMusl;
      });

    };
}
