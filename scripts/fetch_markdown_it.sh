#!/bin/zsh
set -euo pipefail

readonly url='https://unpkg.com/markdown-it@15.0.2/dist/browser/markdown-it.umd.min.js'
readonly expected='635972b985228e8af9f0143647c68616b7a3bb09f6946e7e4a52e43dcf5e7be5'
readonly destination='Sources/KeweiMDReader/Resources/markdown-it.umd.min.js'

mkdir -p "${destination:h}"
curl --fail --location "$url" --output "$destination"
actual=$(shasum -a 256 "$destination" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  print -u2 "markdown-it 校验失败: $actual"
  exit 1
}
