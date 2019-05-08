{
  name = "patchelf";

  description = "A tool for modifying ELF executables and libraries";

  requires = [ "nixpkgs" ];

  provides = deps: rec {

    hydraJobs = import ./release.nix {
      patchelfSrc = deps.self;
      nixpkgs = deps.nixpkgs;
    };

    packages.patchelf = hydraJobs.build.x86_64-linux;

    defaultPackage = packages.patchelf;

  };
}
