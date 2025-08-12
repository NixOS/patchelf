{
  stdenv,
  cmake,
  ninja,
  version,
  src,
}:

stdenv.mkDerivation {
  pname = "patchelf";
  inherit version src;
  nativeBuildInputs = [
    cmake
    ninja
  ];
  doCheck = true;
}
