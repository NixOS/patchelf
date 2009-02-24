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


    rpm_fedora5i386 = makeRPM_i686 (diskImages: diskImages.fedora5i386) 20;
    rpm_fedora9i386 = makeRPM_i686 (diskImages: diskImages.fedora9i386) 50;
    rpm_fedora9x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora9x86_64) 50;
    rpm_fedora10i386 = makeRPM_i686 (diskImages: diskImages.fedora10i386) 40;
    rpm_fedora10x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora10x86_64) 40;
    rpm_opensuse103i386 = makeRPM_i686 (diskImages: diskImages.opensuse103i386) 40;

    
    deb_debian40i386 = makeDeb_i686 (diskImages: diskImages.debian40i386) 40;
    deb_debian40x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian40x86_64) 40;
    deb_debian50i386 = makeDeb_i686 (diskImages: diskImages.debian50i386) 30;
    deb_debian50x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64) 30;
    deb_ubuntu804i386 = makeDeb_i686 (diskImages: diskImages.ubuntu804i386) 50;
    deb_ubuntu804x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu804x86_64) 50;
    deb_ubuntu810i386 = makeDeb_i686 (diskImages: diskImages.ubuntu810i386) 40;
    deb_ubuntu810x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu810x86_64) 40;


  };

  
  makeRPM_i686 = makeRPM "i686-linux";
  makeRPM_x86_64 = makeRPM "x86_64-linux";

  makeRPM =
    system: diskImageFun: prio:
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {inherit system;};

    releaseTools.rpmBuild rec {
      name = "patchelf-rpm-${diskImage.name}";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = toString prio; };
    };


  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";
  
  makeDeb =
    system: diskImageFun: prio:
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    }:

    with import nixpkgs.path {inherit system;};

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = toString prio; };
    };


in jobs
