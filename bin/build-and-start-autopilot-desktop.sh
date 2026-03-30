#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

cd "${repo_root}"

app_bin="${repo_root}/target/debug/autopilot-desktop"
shim_root="${repo_root}/target/host-shims"
cccl_root="${shim_root}/cccl"
alsa_dev_root="${shim_root}/alsa-dev"
alsa_lib_root="${shim_root}/alsa-lib"
alsa_pkg_root="${shim_root}/packages"

alsa_runtime_link="/usr/lib/x86_64-linux-gnu/libasound.so"
alsa_runtime_soname="/usr/lib/x86_64-linux-gnu/libasound.so.2"
alsa_pc="${alsa_dev_root}/usr/lib/x86_64-linux-gnu/pkgconfig/alsa.pc"
alsa_include_dir="${alsa_dev_root}/usr/include/alsa"

log() {
    printf '[autopilot-launch] %s\n' "$*"
}

fail() {
    printf '[autopilot-launch] %s\n' "$*" >&2
    exit 1
}

require_command() {
    local name="$1"
    command -v "${name}" >/dev/null 2>&1 || fail "missing required command: ${name}"
}

prepend_env_path() {
    local var_name="$1"
    local value="$2"
    local current="${!var_name:-}"
    if [[ -n "${current}" ]]; then
        printf -v "${var_name}" '%s:%s' "${value}" "${current}"
    else
        printf -v "${var_name}" '%s' "${value}"
    fi
    export "${var_name}"
}

ensure_linux_shims() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        return 0
    fi

    [[ -e /usr/include/cub ]] || fail "missing /usr/include/cub; install CUDA headers or CCCL first"

    local asound_link_source=""
    if [[ -e "${alsa_runtime_link}" ]]; then
        asound_link_source="${alsa_runtime_link}"
    elif [[ -e "${alsa_runtime_soname}" ]]; then
        asound_link_source="${alsa_runtime_soname}"
    else
        fail "missing ${alsa_runtime_link} and ${alsa_runtime_soname}; install the ALSA runtime first"
    fi

    mkdir -p "${cccl_root}" "${alsa_dev_root}" "${alsa_lib_root}" "${alsa_pkg_root}"
    ln -sfn /usr/include/cub "${cccl_root}/cub"

    if [[ ! -f "${alsa_pc}" || ! -d "${alsa_include_dir}" ]]; then
        require_command apt-get
        require_command dpkg-deb

        local deb_path=""
        deb_path="$(find "${alsa_pkg_root}" -maxdepth 1 -type f -name 'libasound2-dev_*.deb' | sort | tail -n 1)"
        if [[ -z "${deb_path}" ]]; then
            log "downloading libasound2-dev into ${alsa_pkg_root}"
            (
                cd "${alsa_pkg_root}"
                apt-get download libasound2-dev
            )
            deb_path="$(find "${alsa_pkg_root}" -maxdepth 1 -type f -name 'libasound2-dev_*.deb' | sort | tail -n 1)"
        fi
        [[ -n "${deb_path}" ]] || fail "failed to obtain a libasound2-dev package"

        log "extracting $(basename "${deb_path}") into ${alsa_dev_root}"
        rm -rf "${alsa_dev_root}/usr"
        dpkg-deb -x "${deb_path}" "${alsa_dev_root}"
    fi

    ln -sfn "${asound_link_source}" "${alsa_lib_root}/libasound.so"

    prepend_env_path PKG_CONFIG_PATH "${alsa_dev_root}/usr/lib/x86_64-linux-gnu/pkgconfig"
    prepend_env_path CPATH "${cccl_root}"
    prepend_env_path CPATH "/usr/include"
    prepend_env_path CPATH "${alsa_dev_root}/usr/include"
    prepend_env_path LIBRARY_PATH "${alsa_lib_root}"
}

ensure_linux_shims

log "building autopilot-desktop"
cargo build -p autopilot-desktop --bin autopilot-desktop

[[ -x "${app_bin}" ]] || fail "expected built binary at ${app_bin}"

log "starting ${app_bin}"
exec "${app_bin}" "$@"
