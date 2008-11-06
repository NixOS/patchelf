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
      buildInputs = [pkgs.autoconf pkgs.automake];
    };

    
  build =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    #, system ? "i686-linux"
    }:

    let system = "i686-linux"; in

    with import "${release.path}/generic-dist" nixpkgs.path;

    nixBuild {
      inherit (pkgsFun {inherit system;}) stdenv;
      name = "patchelf-build";
      src = tarball.path;
    };


  rpm =
    { tarball ? {path = jobs.tarball {};}
    , nixpkgs ? {path = ../nixpkgs;}
    , release ? {path = ../release;}
    #, system ? "i686-linux"
    }:

    let system = "i686-linux"; in

    with import "${release.path}/generic-dist" nixpkgs.path;

    rpmBuild {
      inherit (pkgsFun {inherit system;}) stdenv;
      name = "patchelf-rpm";
      src = tarball.path;
      diskImage = diskImages_i686.fedora9i386;
    };
    
        
}; in jobs
