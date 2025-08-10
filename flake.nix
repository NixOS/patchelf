{
  description = "A tool for modifying ELF executables and libraries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  # dev tooling
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.git-hooks-nix.url = "github:cachix/git-hooks.nix";
  # work around https://github.com/NixOS/nix/issues/7730
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.git-hooks-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
  # work around 7730 and https://github.com/NixOS/nix/issues/7807
  inputs.git-hooks-nix.inputs.flake-compat.follows = "";
  inputs.git-hooks-nix.inputs.gitignore.follows = "";

  outputs =
    inputs@{ self, nixpkgs, ... }:

    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      version = lib.removeSuffix "\n" (builtins.readFile ./version);
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./COPYING
          ./Makefile.am
          ./README.md
          ./completions
          ./configure.ac
          ./m4
          ./patchelf.1
          ./patchelf.spec.in
          ./src
          ./tests
          ./version
        ];
      };

      patchelfFor =
        pkgs:
        pkgs.callPackage ./package.nix {
          inherit version src;
        };

      # We don't apply flake-parts to the whole flake so that non-development attributes
      # load without fetching any development inputs.
      devFlake = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ ./maintainers/flake-module.nix ];
        systems = supportedSystems;
        perSystem =
          { system, ... }:
          {
            _module.args.pkgs = nixpkgs.legacyPackages.${system};
          };
      };

    in

    {
      overlays.default = final: prev: {
        patchelf-new-musl = patchelfFor final.pkgsMusl;
        patchelf-new = patchelfFor final;
      };

      hydraJobs = {
        tarball = pkgs.releaseTools.sourceTarball rec {
          name = "patchelf-tarball";
          inherit version src;
          versionSuffix = ""; # obsolete
          preAutoconf = "echo ${version} > version";

          # portable configure shouldn't have a shebang pointing to the nix store
          postConfigure = ''
            sed -i '1s|^.*$|#!/bin/sh|' ./configure
          '';
          postDist = ''
            cp README.md $out/
            echo "doc readme $out/README.md" >> $out/nix-support/hydra-build-products
          '';
        };

        coverage =
          (pkgs.releaseTools.coverageAnalysis {
            name = "patchelf-coverage";
            src = self.hydraJobs.tarball;
            lcovFilter = [ "*/tests/*" ];
          }).overrideAttrs
            (old: {
              preCheck = ''
                # coverage cflag breaks this target
                NIX_CFLAGS_COMPILE=''${NIX_CFLAGS_COMPILE//--coverage} make -C tests phdr-corruption.so
              '';
            });

        build = forAllSystems (system: self.packages.${system}.patchelf);
        build-sanitized = forAllSystems (
          system:
          self.packages.${system}.patchelf.overrideAttrs (old: {
            configureFlags = [
              "--with-asan "
              "--with-ubsan"
            ];
            # -Wno-unused-command-line-argument is for clang, which does not like
            # our cc wrapper arguments
            CFLAGS = "-Werror -Wno-unused-command-line-argument";
          })
        );

        # x86_64-linux seems to be only working clangStdenv at the moment
        build-sanitized-clang = lib.genAttrs [ "x86_64-linux" ] (
          system:
          self.hydraJobs.build-sanitized.${system}.override {
            stdenv = nixpkgs.legacyPackages.${system}.llvmPackages_latest.libcxxStdenv;
          }
        );

        # To get mingw compiler from hydra cache
        inherit (self.packages.x86_64-linux) patchelf-win32 patchelf-win64;

        release = pkgs.releaseTools.aggregate {
          name = "patchelf-${self.hydraJobs.tarball.version}";
          constituents = [
            self.hydraJobs.tarball
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

      checks = forAllSystems (
        system:
        {
          build = self.hydraJobs.build.${system};
        }
        // devFlake.checks.${system} or { }
      );

      devShells = forAllSystems (
        system:
        let
          mkShell =
            patchelf:
            patchelf.overrideAttrs (
              old:
              let
                pkgs = nixpkgs.legacyPackages.${system};
                modular = devFlake.getSystem pkgs.stdenv.buildPlatform.system;
              in
              {
                env = (old.env or { }) // {
                  _NIX_PRE_COMMIT_HOOKS_CONFIG = "${(pkgs.formats.yaml { }).generate "pre-commit-config.yaml"
                    modular.pre-commit.settings.rawConfig
                  }";
                };
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                  modular.pre-commit.settings.package
                  (pkgs.writeScriptBin "pre-commit-hooks-install" modular.pre-commit.settings.installationScript)
                ];
              }
            );
        in
        {
          glibc = mkShell self.packages.${system}.patchelf;
          default = self.devShells.${system}.glibc;
        }
        // lib.optionalAttrs (system != "i686-linux") {
          musl = mkShell self.packages.${system}.patchelf-musl;
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          patchelfForWindowsStatic =
            pkgs:
            (pkgs.callPackage ./package.nix {
              inherit version src;
              # On windows we use win32 threads to get a static binary,
              # otherwise `-static` below doesn't work.
              stdenv = pkgs.overrideCC pkgs.stdenv (
                pkgs.buildPackages.wrapCC (
                  pkgs.buildPackages.gcc-unwrapped.override ({
                    threadsCross = {
                      model = "win32";
                      package = null;
                    };
                  })
                )
              );
            }).overrideAttrs
              (old: {
                NIX_CFLAGS_COMPILE = "-static";
              });
        in
        {
          patchelf = patchelfFor pkgs;
          default = self.packages.${system}.patchelf;

          # This is a good test to see if packages can be cross-compiled. It also
          # tests if our testsuite uses target-prefixed executable names.
          patchelf-musl-cross = patchelfFor pkgs.pkgsCross.musl64;
          patchelf-netbsd-cross = patchelfFor pkgs.pkgsCross.x86_64-netbsd;
          patchelf-win32 = patchelfForWindowsStatic pkgs.pkgsCross.mingw32;
          patchelf-win64 = patchelfForWindowsStatic pkgs.pkgsCross.mingwW64;
        }
        // lib.optionalAttrs (system != "i686-linux") {
          patchelf-musl = patchelfFor nixpkgs.legacyPackages.${system}.pkgsMusl;
        }
      );

    };
}
