#!/bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

full_main_name="${PWD}/many-syms-main"
full_lib_name="${PWD}/libmany-syms.so"
chmod -w "$full_lib_name" "$full_main_name"

suffix="_special_suffix"

cd "${SCRATCH}"

###############################################################################
# Test that all symbols in the dynamic symbol table will have the expected
# names after renaming.
# Also test that if we rename all symbols back, the symbols are as expected
###############################################################################

list_symbols() {
    nm -D "$@" | awk '{ print $NF }' | sed '/^ *$/d'
}

list_symbols "$full_lib_name" | cut -d@ -f1 | sort -u | awk "{printf \"%s %s${suffix}\n\",\$1,\$1}" > map
list_symbols "$full_lib_name" | cut -d@ -f1 | sort -u | awk "{printf \"%s${suffix} %s\n\",\$1,\$1}" > rmap

${PATCHELF} --rename-dynamic-symbols map --output libmapped.so "$full_lib_name"
${PATCHELF} --rename-dynamic-symbols rmap --output libreversed.so libmapped.so

list_symbols "$full_lib_name" | sort > orig_syms
list_symbols libmapped.so | sort > map_syms
list_symbols libreversed.so | sort > rev_syms

diff orig_syms rev_syms > diff_orig_syms_rev_syms || exit 1

# Renamed symbols that match version numbers will be printed with version instead of them being ommited
#     CXXABI10 is printed as CXXABI10
# but CXXABI10_renamed is printed as CXXABI10_renamed@@CXXABI10
# awk is used to remove these cases so that we can match the "mapped" symbols to original symbols
sed "s/${suffix}//" map_syms | awk -F @ '{ if ($1 == $2 || $1 == $3) { print $1; } else { print $0; }}' | sort > map_syms_r
diff orig_syms map_syms_r > diff_orig_syms_map_syms_r || exit 1

###############################################################################
# Check the relocation tables after renaming
###############################################################################

print_relocation_table() {
    readelf -W -r "$1" | awk '{ printf "%s\n",$5 }' | cut -f1 -d@
}

print_relocation_table "$full_lib_name" > orig_rel
print_relocation_table libmapped.so > map_rel
print_relocation_table libreversed.so > rev_rel

diff orig_rel rev_rel > diff_orig_rel_rev_rel || exit 1
sed "s/${suffix}//" map_rel > map_rel_r
diff orig_rel map_rel_r > diff_orig_rel_map_rel_r || exit 1

###############################################################################
# Test that the hash table is correctly updated.
# For this to work, we need to rename symbols and actually use the library
# Here we:
#    1. Create a map from all symbols in libstdc++.so as "sym sym_special_suffix"
#    2. Copy Patchelf and all of its transitive library dependencies into a new directory
#    3. Rename symbols in Patchelf and all dependencies according to the map
#    4. Run patchelf with the modified dependencies
###############################################################################

echo "# Create the map"
list_symbols --defined-only "$full_lib_name" | cut -d@ -f1 | sort -u | awk "{printf \"%s %s${suffix}\n\",\$1,\$1}" > map

echo "# Copy all dependencies"
mkdir env
cd env
cp "$full_lib_name" "$full_main_name" .

echo "# Apply renaming"
chmod +w ./*
${PATCHELF} --rename-dynamic-symbols ../map ./*

echo "# Run the patched tool and libraries"
env LD_BIND_NOW=1 LD_LIBRARY_PATH="${PWD}" ./many-syms-main

# Test that other switches still work when --rename-dynamic-symbols has no effect
echo "SYMBOL_THAT_DOESNT_EXIST ANOTHER_NAME" > map
${PATCHELF} --set-rpath changed_rpath --rename-dynamic-symbols map --output libnewrpath.so "$full_lib_name"
[ "$(${PATCHELF} --print-rpath libnewrpath.so)" = changed_rpath ] || exit 1

