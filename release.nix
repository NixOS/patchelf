let jobs = rec {


  tarball =
    { patchelfSrc ? {path = ./.;}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    }:
    
    with import "${release.path}/generic-dist" nixpkgs.path;
    
    makeSourceTarball {
      inherit (pkgs) stdenv;
      name = "patchelf-tarball";
      src = patchelfSrc;
      buildInputs = [pkgs.autoconf pkgs.automake pkgs.pan];
    };


  coverage =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    }:

    with import "${release.path}/generic-dist" nixpkgs.path;

    coverageAnalysis {
      inherit (pkgs) stdenv;
      name = "patchelf-coverage";
      src = tarball.path;
    };


  build =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    , system ? "i686-linux"
    }:

    with import "${release.path}/generic-dist" nixpkgs.path;

    nixBuild {
      inherit (pkgsFun {inherit system;}) stdenv;
      name = "patchelf-build";
      src = tarball.path;
      postInstall = ''
        echo "doc readme $out/share/doc/patchelf/README" >> $out/nix-support/hydra-build-products
      '';
    };


  rpm =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    }:

    with import "${release.path}/generic-dist" nixpkgs.path;

    rpmBuild {
      inherit (pkgs) stdenv;
      name = "patchelf-rpm";
      src = tarball.path;
      diskImage = diskImages_i686.fedora9i386;
    };

            
}; in jobs
