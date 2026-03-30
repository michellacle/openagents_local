#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
app_bin="${repo_root}/target/debug/autopilot-desktop"

if [[ ! -x "${app_bin}" ]]; then
    printf '[autopilot-launch] missing built binary at %s\n' "${app_bin}" >&2
    printf '[autopilot-launch] run %s first\n' "${repo_root}/bin/build-and-start-autopilot-desktop.sh" >&2
    exit 1
fi

cd "${repo_root}"
exec "${app_bin}" "$@"
