{ patchelfSrc ? { outPath = ./.; revCount = 1234; shortRev = "abcdef"; }
, officialRelease ? false
}:

let

  pkgs = import <nixpkgs> { };


  jobs = rec {


    tarball =
      pkgs.releaseTools.sourceTarball rec {
        name = "patchelf-tarball";
        version = builtins.readFile ./version + (if officialRelease then "" else "pre${toString patchelfSrc.revCount}_${patchelfSrc.shortRev}");
        versionSuffix = ""; # obsolete
        src = patchelfSrc;
        preAutoconf = "echo ${version} > version";
        postDist = ''
          cp README $out/
          echo "doc readme $out/README" >> $out/nix-support/hydra-build-products
        '';
      };


    coverage =
      pkgs.releaseTools.coverageAnalysis {
        name = "patchelf-coverage";
        src = tarball;
        lcovFilter = ["*/tests/*"];
      };


    build = pkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" "x86_64-freebsd" "i686-freebsd" "x86_64-darwin" /* "i686-solaris" "i686-cygwin" */ ] (system:

      with import <nixpkgs> { inherit system; };

      releaseTools.nixBuild {
        name = "patchelf";
        src = tarball;
        doCheck = !stdenv.isDarwin && system != "i686-cygwin" && system != "i686-solaris";
      });


    rpm_fedora5i386 = makeRPM_i686 (diskImages: diskImages.fedora5i386) 10;
    rpm_fedora9i386 = makeRPM_i686 (diskImages: diskImages.fedora9i386) 10;
    rpm_fedora9x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora9x86_64) 10;
    rpm_fedora10i386 = makeRPM_i686 (diskImages: diskImages.fedora10i386) 20;
    rpm_fedora10x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora10x86_64) 20;
    rpm_fedora11i386 = makeRPM_i686 (diskImages: diskImages.fedora11i386) 30;
    rpm_fedora11x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora11x86_64) 30;
    rpm_fedora12i386 = makeRPM_i686 (diskImages: diskImages.fedora12i386) 40;
    rpm_fedora12x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora12x86_64) 40;
    rpm_fedora13i386 = makeRPM_i686 (diskImages: diskImages.fedora13i386) 50;
    rpm_fedora13x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora13x86_64) 50;
    rpm_fedora16i386 = makeRPM_i686 (diskImages: diskImages.fedora16i386) 60;
    rpm_fedora16x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora16x86_64) 60;
    rpm_fedora18i386 = makeRPM_i686 (diskImages: diskImages.fedora18i386) 70;
    rpm_fedora18x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora18x86_64) 70;
    rpm_fedora19i386 = makeRPM_i686 (diskImages: diskImages.fedora19i386) 80;
    rpm_fedora19x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora19x86_64) 80;

    rpm_opensuse103i386 = makeRPM_i686 (diskImages: diskImages.opensuse103i386) 40;
    rpm_opensuse110i386 = makeRPM_i686 (diskImages: diskImages.opensuse110i386) 30;
    rpm_opensuse110x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse110x86_64) 30;
    rpm_opensuse111i386 = makeRPM_i686 (diskImages: diskImages.opensuse111i386) 40;
    rpm_opensuse111x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse111x86_64) 40;


    deb_debian40i386 = makeDeb_i686 (diskImages: diskImages.debian40i386) 40;
    deb_debian40x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian40x86_64) 40;
    deb_debian50i386 = makeDeb_i686 (diskImages: diskImages.debian50i386) 50;
    deb_debian50x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64) 50;
    deb_debian60i386 = makeDeb_i686 (diskImages: diskImages.debian60i386) 60;
    deb_debian60x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian60x86_64) 60;
    deb_debian7i386 = makeDeb_i686 (diskImages: diskImages.debian7i386) 70;
    deb_debian7x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian7x86_64) 70;

    deb_ubuntu804i386 = makeDeb_i686 (diskImages: diskImages.ubuntu804i386) 20;
    deb_ubuntu804x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu804x86_64) 20;
    deb_ubuntu810i386 = makeDeb_i686 (diskImages: diskImages.ubuntu810i386) 30;
    deb_ubuntu810x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu810x86_64) 30;
    deb_ubuntu904i386 = makeDeb_i686 (diskImages: diskImages.ubuntu904i386) 40;
    deb_ubuntu904x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu904x86_64) 40;
    deb_ubuntu910i386 = makeDeb_i686 (diskImages: diskImages.ubuntu910i386) 40;
    deb_ubuntu910x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu910x86_64) 40;
    deb_ubuntu1004i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1004i386) 50;
    deb_ubuntu1004x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1004x86_64) 50;
    deb_ubuntu1010i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1010i386) 60;
    deb_ubuntu1010x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1010x86_64) 60;
    deb_ubuntu1110i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1110i386) 70;
    deb_ubuntu1110x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1110x86_64) 70;
    deb_ubuntu1204i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1204i386) 70;
    deb_ubuntu1204x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1204x86_64) 70;
    deb_ubuntu1210i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1210i386) 80;
    deb_ubuntu1210x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1210x86_64) 80;
    deb_ubuntu1304i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1304i386) 85;
    deb_ubuntu1304x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1304x86_64) 85;
    deb_ubuntu1310i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1310i386) 90;
    deb_ubuntu1310x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1310x86_64) 90;


    release = pkgs.releaseTools.aggregate
      { name = "patchelf-${tarball.version}";
        constituents =
          [ tarball
            build.x86_64-linux
            build.i686-linux
            #build.x86_64-freebsd
            #build.i686-freebsd
            build.x86_64-darwin
            rpm_fedora19i386
            rpm_fedora19x86_64
            deb_debian7i386
            deb_debian7x86_64
            deb_ubuntu1310i386
            deb_ubuntu1310x86_64
          ];
        meta.description = "Release-critical builds";
      };

  };


  makeRPM_i686 = makeRPM "i686-linux";
  makeRPM_x86_64 = makeRPM "x86_64-linux";

  makeRPM =
    system: diskImageFun: prio:

    with import <nixpkgs> { inherit system; };

    releaseTools.rpmBuild rec {
      name = "patchelf-rpm";
      src = jobs.tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = prio; };
    };


  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";

  makeDeb =
    system: diskImageFun: prio:

    with import <nixpkgs> { inherit system; };

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = jobs.tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = prio; };
    };


in jobs
