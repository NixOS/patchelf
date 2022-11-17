{ stdenv, buildPackages, autoreconfHook, version, src, overrideCC }:
let
  # on windows we use win32 threads to get a fully static binary
  gcc = buildPackages.wrapCC (buildPackages.gcc-unwrapped.override ({
    threadsCross = {
      model = "win32";
      package = null;
    };
  }));

  stdenv' = if (stdenv.cc.isGNU && stdenv.targetPlatform.isWindows) then
    overrideCC stdenv gcc
  else
    stdenv;
in
stdenv'.mkDerivation {
  pname = "patchelf";
  inherit version src;
  nativeBuildInputs = [ autoreconfHook ];
  doCheck = true;
}
