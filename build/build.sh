#! /bin/bash


mkdir -p .tmp
BUILD_TEMP=$(mktemp -d -p .tmp)
VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' src/giv.sh)
DIST_DIR="./dist/${VERSION}"

printf "Building GIV CLI version %s...\n" "${VERSION}"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

FPM_INSTALLED="false"
# Check for fpm, try to install if missing
if ! command -v fpm >/dev/null 2>&1; then
    echo "Trying: gem install dotenv fpm"
    if gem install dotenv fpm; then
        echo "fpm installed via gem."
    fi
fi

if ! command -v fpm >/dev/null 2>&1; then
    cat >&2 <<EOF
Error: fpm is not installed and automatic installation failed.

Manual installation instructions:
- See https://fpm.readthedocs.io/en/latest/installation.html
- On macOS: gem install fpm
- On Linux (Debian/Ubuntu): sudo apt-get install ruby ruby-dev build-essential && sudo gem install --no-document fpm
- On Linux (Fedora): sudo dnf install ruby ruby-devel make gcc && sudo gem install --no-document fpm
- Or see the docs for more options.
EOF
    FPM_INSTALLED="false"
else
    FPM_INSTALLED="true"
fi

mkdir -p "${BUILD_TEMP}/package"
cp -r src templates docs "${BUILD_TEMP}/package/"
printf 'Copied src templates docs to %s\n' "${BUILD_TEMP}/package/"
cp README.md "${BUILD_TEMP}/package/docs"
mv "${BUILD_TEMP}/package/src/giv.sh" "${BUILD_TEMP}/package/src/giv"
printf "Using build temp directory: %s\n" "${BUILD_TEMP}"

# Collect file lists for setup.py
SH_FILES=$(find "${BUILD_TEMP}/package/src" -type f -name '*.sh' -print0 | xargs -0 -I{} bash -c 'printf "src/%s " "$(basename "{}")"')
TEMPLATE_FILES=$(find "${BUILD_TEMP}/package/templates" -type f -print0 | xargs -0 -I{} bash -c 'printf "templates/%s " "$(basename "{}")"')
DOCS_FILES=$(find "${BUILD_TEMP}/package/docs" -type f -print0 | xargs -0 -I{} bash -c 'printf "docs/%s " "$(basename "{}")"')


export SH_FILES TEMPLATE_FILES DOCS_FILES

./build/npm/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/pypi/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/homebrew/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/scoop/build.sh "${VERSION}" "${BUILD_TEMP}"
if [ "${FPM_INSTALLED}" = "true" ]; then
    ./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "deb"
    ./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "rpm"
fi
./build/snap/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/flatpak/build.sh "${VERSION}" "${BUILD_TEMP}"

#rm -rf "${BUILD_TEMP}"
printf "Build completed. Files are in %s\n" "${DIST_DIR}"
