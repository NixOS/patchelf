{nixpkgs ? ../nixpkgs}:

let

  pkgs = import nixpkgs {};


  jobs = {


    tarball =
      { patchelfSrc ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      }:

      pkgs.releaseTools.sourceTarball {
        name = "patchelf-tarball";
        version = builtins.readFile ./version;
        src = patchelfSrc;
        inherit officialRelease;
        postDist = ''
          cp README $out/
          echo "doc readme $out/README" >> $out/nix-support/hydra-build-products
        '';
      };


    coverage =
      { tarball ? jobs.tarball {}
      }:

      pkgs.releaseTools.coverageAnalysis {
        name = "patchelf-coverage";
        src = tarball;
        lcovFilter = ["*/tests/*"];
      };


    build =
      { tarball ? jobs.tarball {}
      , system ? "i686-linux"
      }:

      with import nixpkgs {inherit system;};

      releaseTools.nixBuild {
        name = "patchelf";
        src = tarball;
        doCheck = system != "i686-darwin" && system != "i686-cygwin";
      };


    rpm_fedora5i386 = makeRPM_i686 (diskImages: diskImages.fedora5i386) 20;
    rpm_fedora9i386 = makeRPM_i686 (diskImages: diskImages.fedora9i386) 30;
    rpm_fedora9x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora9x86_64) 30;
    rpm_fedora10i386 = makeRPM_i686 (diskImages: diskImages.fedora10i386) 40;
    rpm_fedora10x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora10x86_64) 40;
    rpm_fedora11i386 = makeRPM_i686 (diskImages: diskImages.fedora11i386) 50;
    rpm_fedora11x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora11x86_64) 50;
    rpm_opensuse103i386 = makeRPM_i686 (diskImages: diskImages.opensuse103i386) 40;
    rpm_opensuse110i386 = makeRPM_i686 (diskImages: diskImages.opensuse110i386) 30;
    rpm_opensuse110x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse110x86_64) 30;
    rpm_opensuse111i386 = makeRPM_i686 (diskImages: diskImages.opensuse111i386) 40;
    rpm_opensuse111x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse111x86_64) 40;

    
    deb_debian40i386 = makeDeb_i686 (diskImages: diskImages.debian40i386) 40;
    deb_debian40x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian40x86_64) 40;
    deb_debian50i386 = makeDeb_i686 (diskImages: diskImages.debian50i386) 30;
    deb_debian50x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64) 30;
    deb_ubuntu804i386 = makeDeb_i686 (diskImages: diskImages.ubuntu804i386) 30;
    deb_ubuntu804x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu804x86_64) 30;
    deb_ubuntu810i386 = makeDeb_i686 (diskImages: diskImages.ubuntu810i386) 40;
    deb_ubuntu810x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu810x86_64) 40;
    deb_ubuntu904i386 = makeDeb_i686 (diskImages: diskImages.ubuntu904i386) 50;
    deb_ubuntu904x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu904x86_64) 50;


  };

  
  makeRPM_i686 = makeRPM "i686-linux";
  makeRPM_x86_64 = makeRPM "x86_64-linux";

  makeRPM =
    system: diskImageFun: prio:
    { tarball ? jobs.tarball {}
    }:

    with import nixpkgs {inherit system;};

    releaseTools.rpmBuild rec {
      name = "patchelf-rpm";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = prio; };
    };


  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";
  
  makeDeb =
    system: diskImageFun: prio:
    { tarball ? jobs.tarball {}
    }:

    with import nixpkgs {inherit system;};

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = prio; };
    };


in jobs
