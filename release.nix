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


    build = pkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" /* "x86_64-freebsd" "i686-freebsd" */ "x86_64-darwin" /* "i686-solaris" "i686-cygwin" */ ] (system:

      with import <nixpkgs> { inherit system; };

      releaseTools.nixBuild {
        name = "patchelf";
        src = tarball;
        doCheck = !stdenv.isDarwin && system != "i686-cygwin" && system != "i686-solaris";
        buildInputs = lib.optionals stdenv.isLinux [ acl attr ];
      });


    rpm_fedora5i386 = makeRPM_i686 (diskImages: diskImages.fedora5i386);
    rpm_fedora9i386 = makeRPM_i686 (diskImages: diskImages.fedora9i386);
    rpm_fedora9x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora9x86_64);
    rpm_fedora10i386 = makeRPM_i686 (diskImages: diskImages.fedora10i386);
    rpm_fedora10x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora10x86_64);
    rpm_fedora11i386 = makeRPM_i686 (diskImages: diskImages.fedora11i386);
    rpm_fedora11x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora11x86_64);
    rpm_fedora12i386 = makeRPM_i686 (diskImages: diskImages.fedora12i386);
    rpm_fedora12x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora12x86_64);
    rpm_fedora13i386 = makeRPM_i686 (diskImages: diskImages.fedora13i386);
    rpm_fedora13x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora13x86_64);
    rpm_fedora16i386 = makeRPM_i686 (diskImages: diskImages.fedora16i386);
    rpm_fedora16x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora16x86_64);
    rpm_fedora18i386 = makeRPM_i686 (diskImages: diskImages.fedora18i386);
    rpm_fedora18x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora18x86_64);
    rpm_fedora19i386 = makeRPM_i686 (diskImages: diskImages.fedora19i386);
    rpm_fedora19x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora19x86_64);
    rpm_fedora20i386 = makeRPM_i686 (diskImages: diskImages.fedora20i386);
    rpm_fedora20x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora20x86_64);
    rpm_fedora21i386 = makeRPM_i686 (diskImages: diskImages.fedora21i386);
    rpm_fedora21x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora21x86_64);
    rpm_fedora23i386 = makeRPM_i686 (diskImages: diskImages.fedora23i386);
    rpm_fedora23x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora23x86_64);

    rpm_opensuse103i386 = makeRPM_i686 (diskImages: diskImages.opensuse103i386);
    #rpm_opensuse110i386 = makeRPM_i686 (diskImages: diskImages.opensuse110i386);
    #rpm_opensuse110x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse110x86_64);
    rpm_opensuse111i386 = makeRPM_i686 (diskImages: diskImages.opensuse111i386);
    rpm_opensuse111x86_64 = makeRPM_x86_64 (diskImages: diskImages.opensuse111x86_64);


    deb_debian40i386 = makeDeb_i686 (diskImages: diskImages.debian40i386);
    deb_debian40x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian40x86_64);
    deb_debian50i386 = makeDeb_i686 (diskImages: diskImages.debian50i386);
    deb_debian50x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64);
    deb_debian60i386 = makeDeb_i686 (diskImages: diskImages.debian60i386);
    deb_debian60x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian60x86_64);
    deb_debian7i386 = makeDeb_i686 (diskImages: diskImages.debian7i386);
    deb_debian7x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian7x86_64);

    deb_ubuntu804i386 = makeDeb_i686 (diskImages: diskImages.ubuntu804i386);
    deb_ubuntu804x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu804x86_64);
    deb_ubuntu810i386 = makeDeb_i686 (diskImages: diskImages.ubuntu810i386);
    deb_ubuntu810x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu810x86_64);
    deb_ubuntu904i386 = makeDeb_i686 (diskImages: diskImages.ubuntu904i386);
    deb_ubuntu904x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu904x86_64);
    deb_ubuntu910i386 = makeDeb_i686 (diskImages: diskImages.ubuntu910i386);
    deb_ubuntu910x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu910x86_64);
    deb_ubuntu1004i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1004i386);
    deb_ubuntu1004x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1004x86_64);
    deb_ubuntu1010i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1010i386);
    deb_ubuntu1010x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1010x86_64);
    deb_ubuntu1110i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1110i386);
    deb_ubuntu1110x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1110x86_64);
    deb_ubuntu1204i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1204i386);
    deb_ubuntu1204x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1204x86_64);
    deb_ubuntu1210i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1210i386);
    deb_ubuntu1210x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1210x86_64);
    deb_ubuntu1304i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1304i386);
    deb_ubuntu1304x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1304x86_64);
    deb_ubuntu1310i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1310i386);
    deb_ubuntu1310x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1310x86_64);
    deb_ubuntu1404i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1404i386);
    deb_ubuntu1404x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1404x86_64);
    deb_ubuntu1410i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1410i386);
    deb_ubuntu1410x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1410x86_64);
    deb_ubuntu1504i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1504i386);
    deb_ubuntu1504x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1504x86_64);
    deb_ubuntu1510i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1510i386);
    deb_ubuntu1510x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1510x86_64);


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
            deb_ubuntu1404i386
            deb_ubuntu1404x86_64
          ];
        meta.description = "Release-critical builds";
      };

  };


  makeRPM_i686 = makeRPM "i686-linux";
  makeRPM_x86_64 = makeRPM "x86_64-linux";

  makeRPM =
    system: diskImageFun:

    with import <nixpkgs> { inherit system; };

    releaseTools.rpmBuild rec {
      name = "patchelf-rpm";
      src = jobs.tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = 50; };
    };


  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";

  makeDeb =
    system: diskImageFun:

    with import <nixpkgs> { inherit system; };

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = jobs.tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = 50; };
    };


in jobs
