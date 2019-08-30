{
  edition = 201909;

  description = "A tool for modifying ELF executables and libraries";

  outputs = { self, nixpkgs }: rec {

    hydraJobs = import ./release.nix {
      patchelfSrc = self;
      nixpkgs = nixpkgs;
    };

    checks.build = hydraJobs.build.x86_64-linux;

    packages.patchelf = hydraJobs.build.x86_64-linux;

    defaultPackage = packages.patchelf;

  };
}
