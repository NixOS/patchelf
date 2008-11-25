let jobs = rec {


  tarball =
    { patchelfSrc ? {path = ./.;}
    , nixpkgs ? {path = ../nixpkgs;}
    }:
    
    with import nixpkgs.path {};
    
    releaseTools.makeSourceTarball {
      name = "patchelf-tarball";
      src = patchelfSrc;
    };


  coverage =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {};
    
    releaseTools.coverageAnalysis {
      name = "patchelf-coverage";
      src = tarball;
    };


  build =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , system ? "i686-linux"
    }:

    with import nixpkgs.path {inherit system;};

    releaseTools.nixBuild {
      name = "patchelf-build";
      src = tarball;
      postInstall = ''
        echo "doc readme $out/share/doc/patchelf/README" >> $out/nix-support/hydra-build-products
      '';
    };


  rpm =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {};

    releaseTools.rpmBuild {
      name = "patchelf-rpm";
      src = tarball;
      diskImage = vmTools.diskImages.fedora9i386;
    };

            
  deb =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {};

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = tarball;
      diskImage = vmTools.diskImages.debian40i386;
    };

            
}; in jobs
