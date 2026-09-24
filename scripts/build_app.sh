#!/bin/zsh
set -euo pipefail

readonly script_directory="${0:A:h}"
readonly project_directory="${script_directory:h}"
readonly app_name='可微MD极简阅读器'
readonly distribution_directory="${project_directory}/dist"
readonly app_bundle="${distribution_directory}/${app_name}.app"
readonly zip_archive="${distribution_directory}/${app_name}.zip"
readonly release_directory="${project_directory}/.build/arm64-apple-macosx/release"
readonly resource_bundle="${release_directory}/KeweiMDReader_KeweiMDReader.bundle"

cd "${project_directory}"
swift build -c release --arch arm64

test -x "${release_directory}/KeweiMDReader"
test -d "${resource_bundle}"
plutil -lint "${project_directory}/Packaging/Info.plist" >/dev/null

rm -rf "${app_bundle}"
rm -f "${zip_archive}"
mkdir -p "${app_bundle}/Contents/MacOS" "${app_bundle}/Contents/Resources"
cp "${release_directory}/KeweiMDReader" "${app_bundle}/Contents/MacOS/KeweiMDReader"
cp -R "${resource_bundle}" "${app_bundle}/Contents/Resources/"
cp "${project_directory}/Packaging/Info.plist" "${app_bundle}/Contents/Info.plist"

codesign --force --deep --sign - "${app_bundle}"
ditto -c -k --sequesterRsrc --keepParent "${app_bundle}" "${zip_archive}"
codesign --verify --deep --strict "${app_bundle}"

print "已生成：${app_bundle}"
print "已生成：${zip_archive}"
