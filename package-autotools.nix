{
  stdenv,
  autoreconfHook,
  lld,
  mold,
  version,
  src,
}:

stdenv.mkDerivation {
  pname = "patchelf";
  inherit version src;
  nativeBuildInputs = [ autoreconfHook ];
  # Extra linkers so tests/property-rewrite.sh can exercise the layouts they
  # produce; the test degrades gracefully when a linker is missing.
  nativeCheckInputs = [
    lld
    mold
  ];
  doCheck = true;
}
