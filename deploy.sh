#!/usr/bin/env bash
# ===========================================================================
# loadgen deploy script — macOS / Linux
#
#   ./deploy.sh            # create venv + install dependencies
#   ./deploy.sh --run      # ...then start the web app
#   PORT=9000 ./deploy.sh --run
#   PYTHON=python3.13 ./deploy.sh
#
# Requires Python 3.10+ on PATH (as `python3`, or override with $PYTHON).
# ===========================================================================
set -euo pipefail
cd "$(dirname "$0")"

PY="${PYTHON:-python3}"
PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"
RUN=0
for arg in "$@"; do
  [ "$arg" = "--run" ] && RUN=1
done

if ! command -v "$PY" >/dev/null 2>&1; then
  echo "ERROR: '$PY' not found. Install Python 3.10+ or set PYTHON=/path/to/python." >&2
  exit 1
fi

VER="$("$PY" -c 'import sys;print(".".join(map(str,sys.version_info[:2])))')"
echo "==> Using Python $VER ($PY)"

echo "==> Creating virtual environment at ./venv"
"$PY" -m venv venv

echo "==> Upgrading pip + installing requirements"
./venv/bin/python -m pip install --upgrade pip >/dev/null
./venv/bin/python -m pip install -r requirements.txt

echo "==> Verifying pymongo imports"
./venv/bin/python -c "import pymongo, fastapi, uvicorn, apscheduler; print('   deps OK — pymongo', pymongo.version)"

echo ""
echo "Deploy complete. Start the app with:"
echo "    ./venv/bin/python -m uvicorn app:app --host $HOST --port $PORT"
echo "Then open: http://$HOST:$PORT/"

if [ "$RUN" = "1" ]; then
  echo ""
  echo "==> Starting loadgen on http://$HOST:$PORT/  (Ctrl+C to stop)"
  exec ./venv/bin/python -m uvicorn app:app --host "$HOST" --port "$PORT"
fi
