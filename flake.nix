{
  name = "patchelf";

  epoch = 2019;

  description = "A tool for modifying ELF executables and libraries";

  inputs = [ "nixpkgs" ];

  outputs = inputs: rec {

    hydraJobs = import ./release.nix {
      patchelfSrc = inputs.self;
      nixpkgs = inputs.nixpkgs;
    };

    checks.build = hydraJobs.build.x86_64-linux;

    packages.patchelf = hydraJobs.build.x86_64-linux;

    defaultPackage = packages.patchelf;

  };
}
