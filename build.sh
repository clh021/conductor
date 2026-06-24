#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${ROOT_DIR}/dist-binary"
BUILD_DIR="${ROOT_DIR}/build-binary"
PYINSTALLER_SPEC="${BUILD_DIR}/conductor.spec"
OUTPUT_NAME="${OUTPUT_NAME:-conductor}"
MODE="${MODE:-onefile}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

usage() {
    cat <<'EOF'
Usage: ./build.sh [--onefile|--onedir] [--clean] [--name NAME]

Build a standalone Conductor binary with PyInstaller.

Options:
  --onefile       Build a single-file executable (default)
  --onedir        Build an unpacked app directory
  --clean         Remove previous build output before compiling
  --name NAME     Override output executable name
  -h, --help      Show this help message

Environment variables:
  PYTHON_BIN      Python interpreter to use (default: python3)
  MODE            onefile or onedir
  OUTPUT_NAME     Output executable name (default: conductor)
EOF
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

log() {
    printf '[build] %s\n' "$1"
}

fail() {
    printf '[build] ERROR: %s\n' "$1" >&2
    exit 1
}

CLEAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --onefile)
            MODE="onefile"
            ;;
        --onedir)
            MODE="onedir"
            ;;
        --clean)
            CLEAN=1
            ;;
        --name)
            shift
            [ $# -gt 0 ] || fail "--name requires a value"
            OUTPUT_NAME="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
    shift
done

case "$MODE" in
    onefile|onedir) ;;
    *)
        fail "MODE must be one of: onefile, onedir"
        ;;
esac

need_cmd "$PYTHON_BIN" || fail "python interpreter not found: $PYTHON_BIN"

cd "$ROOT_DIR"

if [ "$CLEAN" -eq 1 ]; then
    log "Removing previous build output"
    rm -rf "$DIST_DIR" "$BUILD_DIR"
fi

mkdir -p "$DIST_DIR" "$BUILD_DIR"

if ! "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import PyInstaller  # noqa: F401
PY
then
    log "Installing PyInstaller into the local project environment"
    uv sync --group dev
    uv pip install pyinstaller
    PYTHON_BIN="uv run python"
fi

if [ "$PYTHON_BIN" = "uv run python" ]; then
    PY_CMD=(uv run python)
else
    PY_CMD=("$PYTHON_BIN")
fi

log "Preparing PyInstaller build (${MODE})"

SPEC_MODE_FLAG="--onefile"
if [ "$MODE" = "onedir" ]; then
    SPEC_MODE_FLAG="--onedir"
fi

"${PY_CMD[@]}" -m PyInstaller \
    --noconfirm \
    --clean \
    "$SPEC_MODE_FLAG" \
    --name "$OUTPUT_NAME" \
    --distpath "$DIST_DIR" \
    --workpath "$BUILD_DIR/pyinstaller" \
    --specpath "$BUILD_DIR" \
    --paths "$ROOT_DIR/src" \
    --copy-metadata conductor-cli \
    --collect-data conductor \
    --collect-submodules conductor.providers \
    --hidden-import conductor.__main__ \
    "$ROOT_DIR/src/conductor/__main__.py"

if [ "$MODE" = "onefile" ]; then
    ARTIFACT_PATH="${DIST_DIR}/${OUTPUT_NAME}"
else
    ARTIFACT_PATH="${DIST_DIR}/${OUTPUT_NAME}"
fi

[ -e "$ARTIFACT_PATH" ] || fail "build completed but artifact not found: $ARTIFACT_PATH"

log "Binary build complete: $ARTIFACT_PATH"
log "Quick version check"
"$ARTIFACT_PATH" --version || fail "built artifact failed version check"
