{
  description = "A tool for modifying ELF executables and libraries";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.09";

  outputs = { self, nixpkgs }:

    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }
      );

      pkgs = nixpkgsFor.${"x86_64-linux"};

    in

    {

      overlay = final: prev: {

        patchelf-new = final.stdenv.mkDerivation {
          name = "patchelf-${self.hydraJobs.tarball.version}";
          src = "${self.hydraJobs.tarball}/tarballs/*.tar.bz2";
          doCheck = true;
        };

      };

      hydraJobs = {

        tarball =
          pkgs.releaseTools.sourceTarball rec {
            name = "patchelf-tarball";
            version = builtins.readFile ./version
                      + "." + builtins.substring 0 8 self.lastModifiedDate
                      + "." + (self.shortRev or "dirty");
            versionSuffix = ""; # obsolete
            src = self;
            preAutoconf = "echo ${version} > version";
            postDist = ''
              cp README.md $out/
              echo "doc readme $out/README.md" >> $out/nix-support/hydra-build-products
            '';
          };

        coverage =
          pkgs.releaseTools.coverageAnalysis {
            name = "patchelf-coverage";
            src = self.hydraJobs.tarball;
            lcovFilter = ["*/tests/*"];
          };

        build = forAllSystems (system: nixpkgsFor.${system}.patchelf-new);

        release = pkgs.releaseTools.aggregate
          { name = "patchelf-${self.hydraJobs.tarball.version}";
            constituents =
              [ self.hydraJobs.tarball
                self.hydraJobs.build.x86_64-linux
                self.hydraJobs.build.i686-linux
              ];
            meta.description = "Release-critical builds";
          };

      };

      checks = forAllSystems (system: {
        build = self.hydraJobs.build.${system};
      });

      defaultPackage = forAllSystems (system:
        (import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }).patchelf-new
      );

    };
}
