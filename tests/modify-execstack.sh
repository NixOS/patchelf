#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}"/
cp simple-execstack "${SCRATCH}"/
cp libsimple.so "${SCRATCH}"/
cp libsimple-execstack.so "${SCRATCH}"/

cd "${SCRATCH}"


## simple

cp simple backup

if ! ${PATCHELF} --print-execstack simple | grep -q 'execstack: -'; then
	echo "[simple] wrong initial execstack detection"
	${PATCHELF} --print-execstack simple
	exit 1
fi

if ! ${PATCHELF} --clear-execstack simple; then
	echo "[simple] failed noop initial clear"
	exit 1
fi

if ! ${PATCHELF} --set-execstack simple; then
	echo "[simple] failed set"
	exit 1
fi

if ! ${PATCHELF} --print-execstack simple | grep -q 'execstack: X'; then
	echo "[simple] wrong execstack detection after set"
	${PATCHELF} --print-execstack simple
	exit 1
fi

if diff simple backup; then
	echo "[simple] no change after set"
	exit 1
fi

if ! ${PATCHELF} --set-execstack simple; then
	echo "[simple] failed noop set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack simple; then
	echo "[simple] failed clear after set"
	exit 1
fi

if ! ${PATCHELF} --print-execstack simple | grep -q 'execstack: -'; then
	echo "[simple] wrong execstack detection after clear after set"
	${PATCHELF} --print-execstack simple
	exit 1
fi

if ! diff simple backup; then
	echo "[simple] change against backup after clear after set"
	exit 1
fi


## simple-execstack

cp simple-execstack backup

if ! ${PATCHELF} --print-execstack simple-execstack | grep -q 'execstack: X'; then
	echo "[simple-execstack] wrong initial execstack detection"
	${PATCHELF} --print-execstack simple-execstack
	exit 1
fi

if ! ${PATCHELF} --set-execstack simple-execstack; then
	echo "[simple-execstack] failed noop initial set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack simple-execstack; then
	echo "[simple-execstack] failed clear"
	exit 1
fi

if ! ${PATCHELF} --print-execstack simple-execstack | grep -q 'execstack: -'; then
	echo "[simple-execstack] wrong execstack detection after clear"
	${PATCHELF} --print-execstack simple-execstack
	exit 1
fi

if diff simple-execstack backup; then
	echo "[simple-execstack] no change after set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack simple-execstack; then
	echo "[simple-execstack] failed noop clear"
	exit 1
fi

if ! ${PATCHELF} --set-execstack simple-execstack; then
	echo "[simple-execstack] failed set after clear"
	exit 1
fi

if ! ${PATCHELF} --print-execstack simple-execstack | grep -q 'execstack: X'; then
	echo "[simple-execstack] wrong execstack detection after set after clear"
	${PATCHELF} --print-execstack simple-execstack
	exit 1
fi

if ! diff simple-execstack backup; then
	echo "[simple-execstack] change against backup after set after clear"
	exit 1
fi


## libsimple.so

cp libsimple.so backup

if ! ${PATCHELF} --print-execstack libsimple.so | grep -q 'execstack: -'; then
	echo "[libsimple.so] wrong initial execstack detection"
	${PATCHELF} --print-execstack libsimple.so
	exit 1
fi

if ! ${PATCHELF} --clear-execstack libsimple.so; then
	echo "[libsimple.so] failed noop initial clear"
	exit 1
fi

if ! ${PATCHELF} --set-execstack libsimple.so; then
	echo "[libsimple.so] failed set"
	exit 1
fi

if ! ${PATCHELF} --print-execstack libsimple.so | grep -q 'execstack: X'; then
	echo "[libsimple.so] wrong execstack detection after set"
	${PATCHELF} --print-execstack libsimple.so
	exit 1
fi

if diff libsimple.so backup; then
	echo "[libsimple.so] no change after set"
	exit 1
fi

if ! ${PATCHELF} --set-execstack libsimple.so; then
	echo "[libsimple.so] failed noop set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack libsimple.so; then
	echo "[libsimple.so] failed clear after set"
	exit 1
fi

if ! ${PATCHELF} --print-execstack libsimple.so | grep -q 'execstack: -'; then
	echo "[libsimple.so] wrong execstack detection after clear after set"
	${PATCHELF} --print-execstack libsimple.so
	exit 1
fi

if ! diff libsimple.so backup; then
	echo "[libsimple.so] change against backup after clear after set"
	exit 1
fi


## libsimple-execstack.so

cp libsimple-execstack.so backup

if ! ${PATCHELF} --print-execstack libsimple-execstack.so | grep -q 'execstack: X'; then
	echo "[libsimple-execstack.so] wrong initial execstack detection"
	${PATCHELF} --print-execstack libsimple-execstack.so
	exit 1
fi

if ! ${PATCHELF} --set-execstack libsimple-execstack.so; then
	echo "[libsimple-execstack.so] failed noop initial set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack libsimple-execstack.so; then
	echo "[libsimple-execstack.so] failed clear"
	exit 1
fi

if ! ${PATCHELF} --print-execstack libsimple-execstack.so | grep -q 'execstack: -'; then
	echo "[libsimple-execstack.so] wrong execstack detection after clear"
	${PATCHELF} --print-execstack libsimple-execstack.so
	exit 1
fi

if diff libsimple-execstack.so backup; then
	echo "[libsimple-execstack.so] no change after set"
	exit 1
fi

if ! ${PATCHELF} --clear-execstack libsimple-execstack.so; then
	echo "[libsimple-execstack.so] failed noop clear"
	exit 1
fi

if ! ${PATCHELF} --set-execstack libsimple-execstack.so; then
	echo "[libsimple-execstack.so] failed set after clear"
	exit 1
fi

if ! ${PATCHELF} --print-execstack libsimple-execstack.so | grep -q 'execstack: X'; then
	echo "[libsimple-execstack.so] wrong execstack detection after set after clear"
	${PATCHELF} --print-execstack libsimple-execstack.so
	exit 1
fi

if ! diff libsimple-execstack.so backup; then
	echo "[libsimple-execstack.so] change against backup after set after clear"
	exit 1
fi
