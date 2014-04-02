#! /bin/sh -e

echo "Running autoreconf..."
autoreconf -ivf --warnings=all "$@"

echo "Now run './configure' and then 'make' to build PatchELFmod"

