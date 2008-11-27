let


  jobs = rec {


    tarball =
      { patchelfSrc ? {path = ./.; rev = 1234;}
      , nixpkgs ? {path = ../nixpkgs;}
      , officialRelease ? false
      }:

      with import nixpkgs.path {};

      releaseTools.makeSourceTarball {
        name = "patchelf-tarball";
        src = patchelfSrc;
        inherit officialRelease;
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


    rpm_fedora9i386 = makeRPM (diskImages: diskImages.fedora9i386) 50;
    rpm_fedora10i386 = makeRPM (diskImages: diskImages.fedora10i386) 40;
    rpm_opensuse103i386 = makeRPM (diskImages: diskImages.opensuse103i386) 40;

    
    deb_debian40i386 = makeDeb (diskImages: diskImages.debian40i386) 30;
    deb_ubuntu804i386 = makeDeb (diskImages: diskImages.ubuntu804i386) 40;


  };

  
  makeRPM =
    diskImageFun: prio:
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {};

    releaseTools.rpmBuild rec {
      name = "patchelf-rpm-${diskImage.name}";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = toString prio; };
    };


  makeDeb =
    diskImageFun: prio:
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {};

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = toString prio; };
    };


in jobs
