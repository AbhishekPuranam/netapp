#!/usr/bin/env bash
# Pull nmap as a container image and list open TCP ports on a host you own
# or are authorized to scan.
set -euo pipefail

IMAGE="${NMAP_IMAGE:-instrumentisto/nmap}"
TARGET=""
PORT_SPEC=""
USE_HOST_NET=0

usage() {
  cat <<'EOF'
Usage: nmap-open-ports.sh [options] [target]

Download (docker pull) nmap and run it in a container to print open TCP ports.

Arguments:
  target          Host or IP to scan. Default: this machine
                  (host.docker.internal on macOS/Windows Docker Desktop,
                   127.0.0.1 with --network host on Linux).

Options:
  -p, --ports SPEC   Ports to scan (nmap -p). Default: top 100 (-F).
  -n, --host-network Use Docker host networking (Linux).
  -h, --help         Show this help.

Environment:
  NMAP_IMAGE      Image to pull/run (default: instrumentisto/nmap).

Examples:
  ./scripts/nmap-open-ports.sh
  ./scripts/nmap-open-ports.sh 127.0.0.1
  ./scripts/nmap-open-ports.sh -p 22,80,443 192.168.1.10

Only scan systems you are authorized to test.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -p|--ports)
      PORT_SPEC="${2:-}"
      if [[ -z "$PORT_SPEC" ]]; then
        echo "error: --ports requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -n|--host-network)
      USE_HOST_NET=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo "error: unexpected extra argument: $1" >&2
        exit 1
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is required (install Docker Desktop or the Docker engine)" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "error: docker daemon is not running or is not accessible" >&2
  exit 1
fi

os="$(uname -s)"
if [[ -z "$TARGET" ]]; then
  case "$os" in
    Darwin|MINGW*|MSYS*|CYGWIN*)
      TARGET="host.docker.internal"
      ;;
    *)
      TARGET="127.0.0.1"
      USE_HOST_NET=1
      ;;
  esac
fi

echo "Pulling ${IMAGE}..."
docker pull "$IMAGE"

docker_args=(run --rm)
if [[ "$USE_HOST_NET" -eq 1 ]]; then
  docker_args+=(--network host)
fi

nmap_args=(-Pn --open)
if [[ -n "$PORT_SPEC" ]]; then
  nmap_args+=(-p "$PORT_SPEC")
else
  nmap_args+=(-F)
fi
nmap_args+=("$TARGET")

echo "Scanning ${TARGET} for open TCP ports..."
docker "${docker_args[@]}" "$IMAGE" "${nmap_args[@]}"
