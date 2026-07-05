#!/usr/bin/env bash
# Run CCE via the published GHCR container image (ghcr.io/stackgenhq/cce).
set -euo pipefail

cce_image() {
  if [ -n "${CCE_IMAGE:-}" ]; then
    printf '%s' "${CCE_IMAGE}"
    return
  fi
  printf 'ghcr.io/stackgenhq/cce:%s' "${CCE_VERSION:-0.0.5}"
}

cce_install() {
  local image
  image="$(cce_image)"
  echo "Pulling CCE container ${image}"
  docker pull "${image}"
  docker run --rm --user "$(id -u):$(id -g)" "${image}" -version
}

cce_abs_path() {
  local path="$1"
  if [[ "${path}" != /* ]]; then
    path="${GITHUB_WORKSPACE}/${path}"
  fi
  printf '%s' "${path}"
}

cce_invoke() {
  local image="${CCE_IMAGE:-}"
  if [ -z "${image}" ]; then
    image="$(cce_image)"
  fi

  local -a docker_args=(
    docker run --rm
    --user "$(id -u):$(id -g)"
    -v "${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE}"
    -w "${GITHUB_WORKSPACE}"
  )

  local -A mounted=()
  mounted["${GITHUB_WORKSPACE}"]=1
  local path dir
  for path in "$@"; do
    [[ "${path}" == -* ]] && continue
    [[ "${path}" == http://* || "${path}" == https://* ]] && continue
    [[ "${path}" == *,* ]] && continue
    path="$(cce_abs_path "${path}")"
    dir="$(dirname "${path}")"
    if [ -z "${mounted[$dir]+x}" ]; then
      docker_args+=(-v "${dir}:${dir}")
      mounted["$dir"]=1
    fi
  done

  docker_args+=("${image}")
  docker_args+=("$@")
  "${docker_args[@]}"
}
