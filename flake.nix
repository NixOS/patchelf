{
  edition = 201909;

  description = "A tool for modifying ELF executables and libraries";

  outputs = { self, nixpkgs }: rec {

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

    checks.build = hydraJobs.build.x86_64-linux;

    packages.patchelf = (import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    }).patchelf-new;

    defaultPackage = packages.patchelf;

  };
}
