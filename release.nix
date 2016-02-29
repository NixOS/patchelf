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


    build = pkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" /* "x86_64-freebsd" "i686-freebsd"  "x86_64-darwin" "i686-solaris" "i686-cygwin" */ ] (system:

      with import <nixpkgs> { inherit system; };

      releaseTools.nixBuild {
        name = "patchelf";
        src = tarball;
        doCheck = !stdenv.isDarwin && system != "i686-cygwin" && system != "i686-solaris";
        buildInputs = lib.optionals stdenv.isLinux [ acl attr ];
      });


    rpm_fedora20i386 = makeRPM_i686 (diskImages: diskImages.fedora20i386);
    rpm_fedora20x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora20x86_64);
    rpm_fedora21i386 = makeRPM_i686 (diskImages: diskImages.fedora21i386);
    rpm_fedora21x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora21x86_64);
    rpm_fedora23i386 = makeRPM_i686 (diskImages: diskImages.fedora23i386);
    rpm_fedora23x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora23x86_64);

    deb_debian7i386 = makeDeb_i686 (diskImages: diskImages.debian7i386);
    deb_debian7x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian7x86_64);
    deb_debian8i386 = makeDeb_i686 (diskImages: diskImages.debian8i386);
    deb_debian8x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian8x86_64);

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
            #build.x86_64-darwin
            rpm_fedora23i386
            rpm_fedora23x86_64
            deb_debian8i386
            deb_debian8x86_64
            deb_ubuntu1510i386
            deb_ubuntu1510x86_64
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
