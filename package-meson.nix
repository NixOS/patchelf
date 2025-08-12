{
  stdenv,
  meson,
  ninja,
  version,
  src,
}:

stdenv.mkDerivation {
  pname = "patchelf";
  inherit version src;
  nativeBuildInputs = [
    meson
    ninja
  ];
  doCheck = true;
}
