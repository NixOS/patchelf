#! /bin/sh -ue

# Usage: killed_by_signal $?
#
# Returns true if the exit code indicates that the program was killed
# by a signal. This works because the exit code of processes that were
# killed by a signal is 128 plus the signal number.
killed_by_signal() {
    [ "$1" -ge 128 ]
}


# The directory containing all our input files.
TEST_DIR=$(dirname "$(readlink -f "$0")")/invalid-elf

# Each test case is listed here. The names should roughly indicate
# what makes the given ELF file invalid.
TEST_CASES="invalid-shrstrtab-idx invalid-shrstrtab-size invalid-shrstrtab-zero
            invalid-shrstrtab-nonterm invalid-shdr-name invalid-phdr-offset"

# Issue #64 regression test. Test ELF provided by issue submitter.
TEST_CASES=$TEST_CASES' invalid-phdr-issue-64'

# shellcheck disable=SC2034
invalid_shrstrtab_idx_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_shrstrtab_size_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_shrstrtab_zero_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_shrstrtab_nonterm_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_shdr_name_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_phdr_offset_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_phdr_issue_64_MSG='program header table out of bounds'

FAILED_TESTS=""

for tcase in $TEST_CASES; do
    if [ ! -r "$TEST_DIR/$tcase" ]; then
	echo "Cannot read test case: $tcase"
	exit 1
    fi

    ../src/patchelf --output /dev/null "$TEST_DIR/$tcase" && res=$? || res=$?
    if killed_by_signal "$res"; then
	FAILED_TESTS="$FAILED_TESTS $tcase"
    fi

    var=$(echo "$tcase-MSG" | tr '-' '_')
    msg=
    eval "msg=\${$var}"
    ../src/patchelf --output /dev/null "$TEST_DIR/$tcase" 2>&1 |
        grep "$msg" >/dev/null 2>/dev/null
done

if [ -z "$FAILED_TESTS" ]; then
    exit 0
else
    echo "Failed tests: $FAILED_TESTS"
    exit 1
fi
