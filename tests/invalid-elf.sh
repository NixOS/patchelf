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

# Issue #132 regression test. Test ELF provided by issue submitter.
TEST_CASES=$TEST_CASES' invalid-shrink-rpath-issue-132'

# Issue #133 regression test. Test ELFs provided by issue submitter.
set -x
for i in $(seq 0 5); do
    # Not yet fixed!
    if [ "$i" = 3 ]; then continue; fi
    TEST_CASES=$TEST_CASES' invalid-strlen-issue-133-'$i
done
set +x

# Issue #134 regression test. Test ELFs provided by issue submitter.
set -x
for i in $(seq 0 1); do
    TEST_CASES=$TEST_CASES' invalid-null-ptr-issue-134-'$i
done
set +x

# Not yet fixed!
# Issue #132 regression test. Test ELF provided by issue submitter.
#TEST_CASES=$TEST_CASES' invalid-string-index-issue-135'

# Some ELFs are immediately recognized as invalid. Others, we need to
# attempt an operation to notice the problem.

# shellcheck disable=SC2034
invalid_shrstrtab_idx_CMDS=''
# shellcheck disable=SC2034
invalid_shrstrtab_size_CMDS=''
# shellcheck disable=SC2034
invalid_shrstrtab_zero_CMDS=''
# shellcheck disable=SC2034
invalid_shrstrtab_nonterm_CMDS=''
# shellcheck disable=SC2034
invalid_shdr_name_CMDS=''
# shellcheck disable=SC2034
invalid_phdr_offset_CMDS=''
# shellcheck disable=SC2034
invalid_phdr_issue_64_CMDS=''
# shellcheck disable=SC2034
invalid_shrink_rpath_issue_132_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_0_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_1_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_2_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_3_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_4_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_strlen_issue_133_5_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_null_ptr_issue_134_0_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_null_ptr_issue_134_1_CMDS='--shrink-rpath'
# shellcheck disable=SC2034
invalid_string_index_issue_135_CMDS='--shrink-rpath'

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
# shellcheck disable=SC2034
invalid_shrink_rpath_issue_132_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_strlen_issue_133_0_MSG='section name offset out of bounds'
# shellcheck disable=SC2034
invalid_strlen_issue_133_1_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_strlen_issue_133_2_MSG='string table is not zero terminated'
# shellcheck disable=SC2034
invalid_strlen_issue_133_3_MSG='not sure yet'
# shellcheck disable=SC2034
invalid_strlen_issue_133_4_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_strlen_issue_133_5_MSG='string table size is zero'
# shellcheck disable=SC2034
invalid_null_ptr_issue_134_0_MSG='no section headers'
# shellcheck disable=SC2034
invalid_null_ptr_issue_134_1_MSG='no section headers'
# shellcheck disable=SC2034
invalid_string_index_issue_135_MSG='no sure yet'

FAILED_TESTS=""

for tcase in $TEST_CASES; do
    if [ ! -r "$TEST_DIR/$tcase" ]; then
    echo "Cannot read test case: $tcase"
    exit 1
    fi

    var=$(echo "$tcase-CMDS" | tr '-' '_')
    cmds=
    eval "cmds=\${$var}"

    # Want the word-splitting, no arrays in POSIX shell
    # shellcheck disable=SC2086
    ../src/patchelf $cmds --output /dev/null "$TEST_DIR/$tcase" && res=$? || res=$?
    if killed_by_signal "$res"; then
    FAILED_TESTS="$FAILED_TESTS $tcase"
    fi

    var=$(echo "$tcase-MSG" | tr '-' '_')
    msg=
    eval "msg=\${$var}"

    # Want the word-splitting, no arrays in POSIX shell
    # shellcheck disable=SC2086
    ../src/patchelf $cmds --output /dev/null "$TEST_DIR/$tcase" 2>&1 |
        grep "$msg" >/dev/null 2>/dev/null
done

if [ -z "$FAILED_TESTS" ]; then
    exit 0
else
    echo "Failed tests: $FAILED_TESTS"
    exit 1
fi
