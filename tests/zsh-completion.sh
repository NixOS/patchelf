#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")
COMPLETIONS=$(readlink -f "${srcdir:?}/../completions/zsh")
export PATCHELF COMPLETIONS

if ! command -v zsh >/dev/null; then
    echo "skipping test: zsh not found"
    exit 77
fi

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libdir"
cp main "${SCRATCH}"/
cp libfoo.so "${SCRATCH}"/libdir/
${PATCHELF} --add-needed 'libz:x.so' "${SCRATCH}"/main
cp "${SCRATCH}"/main "${SCRATCH}"/-main
cd "${SCRATCH}"

# Sourced by the interactive zsh below; ^T saves the line being edited.
cat > zshrc <<'EOF'
# The completion runs patchelf to list needed libraries.
path=(${PATCHELF:h} $path)
fpath=($COMPLETIONS $fpath)
# So that ~/main in the cases below is ./main.
HOME=$PWD
autoload -Uz compinit && compinit -u -D
bindkey -e
save-line() { print -r -- "$BUFFER" > line; BUFFER=; : > saved }
zle -N save-line
bindkey '^T' save-line
: > ready
EOF

zsh -f <<'EOF'
zmodload zsh/zpty || exit 77
setopt extendedglob
# TERM=emacs would turn off the line editor.
zpty shell TERM=dumb zsh -f -i || exit 77
zpty -w shell 'source ./zshrc'
failed=0

# Waits for file $1 to appear, reading the shell's output into $output.
await() {
    local chunk deadline=$(( SECONDS + 60 ))
    until [[ -e $1 ]]; do
        (( SECONDS < deadline )) || { print -rl -- "zsh did not respond. Its output:" "$output"; exit 1 }
        zpty -r -t shell chunk && output+=$chunk || sleep 0.1
    done
    while zpty -r -t shell chunk; do output+=$chunk; done
}

# Types $1, presses Tab and checks that the line became $2 without errors.
check_completed() {
    output=
    rm -f saved
    zpty -w -n shell "$1"$'\t\C-t'
    await saved
    if [[ $(<line) != "$2" ]]; then
        print -r -- "'$1<Tab>' gave '$(<line)', expected '$2'"
        failed=1
    fi
    # zsh reports errors as "function:line: message".
    if [[ $output == *:[0-9]##:\ * ]]; then
        print -r -- "'$1<Tab>' printed an error: ${(M)${(f)output}:#*:[0-9]##:\ *}"
        failed=1
    fi
}

# Types $1, presses Tab and checks that nothing was completed.
check_unchanged() { check_completed "$1" "$1" }

# Runs a check that is expected to fail, and fails if it passes instead.
failing() {
    local was_failed=$failed
    failed=0
    "$@" > /dev/null
    if (( failed )); then
        failed=$was_failed
    else
        print -r -- "'$2<Tab>' passed, so it shouldn't be marked F"
        failed=1
    fi
}
alias F=failing

await ready
check_completed 'patchelf ma'                                'patchelf main '
check_completed 'patchelf --print-interpreter ma'            'patchelf --print-interpreter main '
check_completed 'patchelf --print-needed --print-rp'         'patchelf --print-needed --print-rpath '
check_unchanged 'patchelf --version ma'
check_completed 'patchelf --clear-execstack --set-e'         'patchelf --clear-execstack --set-execstack '
F check_completed 'patchelf --set-os-abi hp'                   'patchelf --set-os-abi hp-ux '
F check_completed 'patchelf --add-needed a.so --add-ne'        'patchelf --add-needed a.so --add-needed '
F check_completed 'patchelf --set-rpath /:li'                  'patchelf --set-rpath /:libdir/'
F check_completed 'patchelf --allowed-rpath-prefixes /:li'     'patchelf --allowed-rpath-prefixes /:libdir/'
F check_completed 'patchelf --clear-sy'                        'patchelf --clear-symbol-version '
F check_completed 'patchelf --no-cl'                           'patchelf --no-clobber-old-sections '
check_unchanged 'patchelf --interp'
F check_completed 'patchelf -- --print-i'                      'patchelf -- --print-interpreter '
check_completed 'patchelf --output out ma'                   'patchelf --output out main '
F check_unchanged 'patchelf --output out main ma'
check_completed 'patchelf --interpreter /x --output out ma'  'patchelf --interpreter /x --output out main '
F check_completed 'patchelf --debug main --remove-needed libf' 'patchelf --debug main --remove-needed libfoo.so '
F check_completed 'patchelf --debug main --remove-needed libz' 'patchelf --debug main --remove-needed libz:x.so '
check_unchanged 'patchelf main "--add-needed" libdir/libfoo.so --remove-needed libb'
F check_completed 'patchelf -main --remove-needed libz'        'patchelf -main --remove-needed libz:x.so '
F check_completed 'patchelf ~/main --remove-needed libz'       'patchelf ~/main --remove-needed libz:x.so '
check_completed 'patchelf --remove-needed libd'              'patchelf --remove-needed libdir/'
# \eb\C-b puts the cursor just after libf.
check_completed $'patchelf --remove-needed libf main\eb\C-b' 'patchelf --remove-needed libfoo.so  main'
# libbar.so is needed by the new name, libdir/libfoo.so, but not by main.
check_completed $'patchelf main --replace-needed libb libdir/libfoo.so\eb\C-b' \
                'patchelf main --replace-needed libb libdir/libfoo.so'
exit $failed
EOF
