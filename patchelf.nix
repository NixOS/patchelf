{ stdenv, autoreconfHook, version, src }:

stdenv.mkDerivation {
  pname = "patchelf";
  inherit version src;
  nativeBuildInputs = [ autoreconfHook ];
  doCheck = true;
}
