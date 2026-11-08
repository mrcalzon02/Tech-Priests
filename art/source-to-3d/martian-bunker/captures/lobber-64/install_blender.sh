#!/usr/bin/env bash
set -euo pipefail
blender_archive_sha=8019580ee1b7262e505f4196a00237ccf743c88d205b38d34201510676e60b09
blender_root=.tools/blender-5.0.1-linux-x64
if [[ -x "$blender_root/blender" ]] && [[ -f "$blender_root/.archive-sha256" ]] && [[ "$(cat "$blender_root/.archive-sha256")" == "$blender_archive_sha" ]]; then
  blender_version_output="$($blender_root/blender --version)"
  [[ "$blender_version_output" == 'Blender 5.0.1'* ]]
  echo 'Verified cached Blender 5.0.1'
  exit 0
fi
mkdir -p .tools
blender_download_dir="$(mktemp -d)"
trap 'rm -rf "$blender_download_dir"' EXIT
for blender_origin in https://mirror.blender.org https://download.blender.org; do
  blender_url="$blender_origin/release/Blender5.0/blender-5.0.1-linux-x64.tar.xz"
  if curl --fail --location --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 240 "$blender_url" --output "$blender_download_dir/blender.tar.xz"; then
    printf '%s  %s\n' "$blender_archive_sha" "$blender_download_dir/blender.tar.xz" | sha256sum --check
    tar -xf "$blender_download_dir/blender.tar.xz" -C .tools
    printf '%s\n' "$blender_archive_sha" > "$blender_root/.archive-sha256"
    blender_version_output="$($blender_root/blender --version)"
    [[ "$blender_version_output" == 'Blender 5.0.1'* ]]
    echo 'Installed checksum-verified Blender 5.0.1'
    exit 0
  fi
done
echo 'Both official Blender download endpoints failed after bounded retries' >&2
exit 1
