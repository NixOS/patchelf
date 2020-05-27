{
  description = "A tool for modifying ELF executables and libraries";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";

  outputs = { self, nixpkgs }:

    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in

    rec {

      overlay = final: prev: {

        patchelf-new = final.stdenv.mkDerivation {
          name = "patchelf-${hydraJobs.tarball.version}";
          src = "${hydraJobs.tarball}/tarballs/*.tar.bz2";
        };

      };

      hydraJobs = import ./release.nix {
        patchelfSrc = self;
        nixpkgs = nixpkgs;
      };

      checks = forAllSystems (system: {
        build = hydraJobs.build.${system};
      });

      defaultPackage = forAllSystems (system:
        (import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }).patchelf-new
      );

    };
}
