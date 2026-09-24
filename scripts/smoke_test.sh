#!/bin/zsh
set -euo pipefail

readonly script_directory="${0:A:h}"
readonly project_directory="${script_directory:h}"
readonly app_name='可微MD极简阅读器'
readonly app_bundle="${project_directory}/dist/${app_name}.app"
readonly binary="${app_bundle}/Contents/MacOS/KeweiMDReader"
readonly info_plist="${app_bundle}/Contents/Info.plist"
readonly resource_bundle="${app_bundle}/Contents/Resources/KeweiMDReader_KeweiMDReader.bundle"
readonly app_icon="${app_bundle}/Contents/Resources/AppIcon.icns"
readonly zip_archive="${project_directory}/dist/${app_name}.zip"
readonly fixture="${project_directory}/Fixtures/sample.md"
readonly renderer="${project_directory}/Sources/KeweiMDReader/Resources/markdown-it.umd.min.js"
readonly expected_renderer_hash='635972b985228e8af9f0143647c68616b7a3bb09f6946e7e4a52e43dcf5e7be5'

cd "${project_directory}"

test -d "${app_bundle}"
test -x "${binary}"
test -f "${info_plist}"
test -d "${resource_bundle}"
test -f "${app_icon}"
test -f "${zip_archive}"
plutil -lint "${info_plist}" >/dev/null
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDocumentTypes:0:CFBundleTypeRole' "${info_plist}")" = 'Viewer'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "${info_plist}")" = 'AppIcon'
codesign --verify --deep --strict "${app_bundle}"
lipo -archs "${binary}" | tr ' ' '\n' | grep -qx 'arm64'
test "$(shasum -a 256 "${renderer}" | awk '{print $1}')" = "${expected_renderer_hash}"

readonly fixture_hash_before="$(shasum -a 256 "${fixture}" | awk '{print $1}')"
swift test --filter DocumentLoaderTests
readonly fixture_hash_after="$(shasum -a 256 "${fixture}" | awk '{print $1}')"
test "${fixture_hash_before}" = "${fixture_hash_after}"

print '烟雾测试通过：App 完整、图标已嵌入、签名有效、arm64 架构正确、离线资源固定、Markdown 原文件未被修改。'
