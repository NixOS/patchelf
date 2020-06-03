{ patchelfSrc ? { outPath = ./.; revCount = 1234; shortRev = "abcdef"; }
, nixpkgs ? builtins.fetchTarball https://github.com/NixOS/nixpkgs-channels/archive/nixos-20.03.tar.gz
, officialRelease ? false
}:

let

  pkgs = import nixpkgs { system = builtins.currentSystem or "x86_64-linux"; };


  jobs = rec {


    tarball =
      pkgs.releaseTools.sourceTarball rec {
        name = "patchelf-tarball";
        version = builtins.readFile ./version +
                  (if officialRelease then "" else
                    "." +
                    ((if patchelfSrc ? lastModifiedDate
                      then builtins.substring 0 8 patchelfSrc.lastModifiedDate
                      else toString patchelfSrc.revCount or 0)
                    + "." + patchelfSrc.shortRev));
        versionSuffix = ""; # obsolete
        src = patchelfSrc;
        preAutoconf = "echo ${version} > version";
        postDist = ''
          cp README.md $out/
          echo "doc readme $out/README.md" >> $out/nix-support/hydra-build-products
        '';
      };


    coverage =
      pkgs.releaseTools.coverageAnalysis {
        name = "patchelf-coverage";
        src = tarball;
        lcovFilter = ["*/tests/*"];
      };


    build = pkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" /* "x86_64-freebsd" "i686-freebsd"  "x86_64-darwin" "i686-solaris" "i686-cygwin" */ ] (system:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "patchelf";
        src = tarball;
        doCheck = !stdenv.isDarwin && system != "i686-cygwin" && system != "i686-solaris";
        buildInputs = lib.optionals stdenv.isLinux [ acl attr ];
        isReproducible = system != "aarch64-linux"; # ARM machines are still on Nix 1.11
      });

    /*
    rpm_fedora27x86_64 = makeRPM_x86_64 (diskImages: diskImages.fedora27x86_64);

    deb_debian9i386 = makeDeb_i686 (diskImages: diskImages.debian9i386);
    deb_debian9x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian9x86_64);

    deb_ubuntu1804i386 = makeDeb_i686 (diskImages: diskImages.ubuntu1804i386);
    deb_ubuntu1804x86_64 = makeDeb_x86_64 (diskImages: diskImages.ubuntu1804x86_64);
    */


    release = pkgs.releaseTools.aggregate
      { name = "patchelf-${tarball.version}";
        constituents =
          [ tarball
            build.x86_64-linux
            build.i686-linux
            /*
            rpm_fedora27x86_64
            deb_debian9i386
            deb_debian9x86_64
            deb_ubuntu1804i386
            deb_ubuntu1804x86_64
            */
          ];
        meta.description = "Release-critical builds";
      };

  };


  makeRPM_i686 = makeRPM "i686-linux";
  makeRPM_x86_64 = makeRPM "x86_64-linux";

  makeRPM =
    system: diskImageFun:

    with import nixpkgs { inherit system; };

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

    with import nixpkgs { inherit system; };

    releaseTools.debBuild {
      name = "patchelf-deb";
      src = jobs.tarball;
      diskImage = diskImageFun vmTools.diskImages;
      meta = { schedulingPriority = 50; };
    };


in jobs
