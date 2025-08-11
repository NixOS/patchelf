{
  lib,
  getSystem,
  inputs,
  ...
}:

{
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  perSystem =
    { config, pkgs, ... }:
    {

      # https://flake.parts/options/git-hooks-nix#options
      pre-commit.settings = {
        hooks = {
          # Conflicts are usually found by other checks, but not those in docs,
          # and potentially other places.
          check-merge-conflicts.enable = true;
          # built-in check-merge-conflicts seems ineffective against those produced by mergify backports
          check-merge-conflicts-2 = {
            enable = true;
            entry = "${pkgs.writeScript "check-merge-conflicts" ''
              #!${pkgs.runtimeShell}
              conflicts=false
              for file in "$@"; do
                if grep --with-filename --line-number -E '^>>>>>>> ' -- "$file"; then
                  conflicts=true
                fi
              done
              if $conflicts; then
                echo "ERROR: found merge/patch conflicts in files"
                exit 1
              fi
            ''}";
          };
          nixfmt-rfc-style = {
            enable = true;
          };
          clang-format = {
            enable = true;
            # https://github.com/cachix/git-hooks.nix/pull/532
            package = pkgs.llvmPackages_latest.clang-tools;
            # Not yet formatted
            excludes = [
              ''^src/elf.h$''
              ''^src/patchelf.cc$''
              ''^src/patchelf.h$''
              ''^tests/bar.c$''
              ''^tests/foo.c$''
              ''^tests/main.c$''
              ''^tests/no-rpath.c$''
              ''^tests/simple.c$''
              ''^tests/too-many-strtab.c$''
              ''^tests/void.c$''
            ];
          };
          shellcheck = {
            enable = true;
          };
        };
      };
    };

  # We'll be pulling from this in the main flake
  flake.getSystem = getSystem;
}
