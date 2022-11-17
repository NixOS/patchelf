{
  description = "A tool for modifying ELF executables and libraries";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:

    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
      pkgs = nixpkgs.legacyPackages.x86_64-linux;


      patchelfFor = pkgs: let
        # this is only
      in pkgs.callPackage ./patchelf.nix {
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

        # To get mingw compiler from hydra cache
        inherit (self.packages.x86_64-linux) patchelf-win32 patchelf-win64;

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

      packages = forAllSystems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        patchelf = patchelfFor pkgs;
        default = self.packages.${system}.patchelf;

        # This is a good test to see if packages can be cross-compiled. It also
        # tests if our testsuite uses target-prefixed executable names.
        patchelf-musl-cross = patchelfFor pkgs.pkgsCross.musl64;
        patchelf-netbsd-cross = patchelfFor pkgs.pkgsCross.x86_64-netbsd;

        patchelf-win32 = (patchelfFor pkgs.pkgsCross.mingw32).overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = "-static";
        });
        patchelf-win64 = (patchelfFor pkgs.pkgsCross.mingwW64).overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = "-static";
        });
      } // nixpkgs.lib.optionalAttrs (system != "i686-linux") {
        patchelf-musl = patchelfFor nixpkgs.legacyPackages.${system}.pkgsMusl;
      });

    };
}
