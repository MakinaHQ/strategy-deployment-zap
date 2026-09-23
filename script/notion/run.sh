#!/usr/bin/env bash
# Runs the forge deployment scripts for one machine exported by export-machines.mjs.
#
#   script/notion/run.sh <Name> encode                 fill peripheryParams in the machine input file
#   script/notion/run.sh <Name> schedule [forge args]  scheduleDeployment (zap owner)
#   script/notion/run.sh <Name> create   [forge args]  createMachine (executor, after the delay)
#
# schedule/create run in VIEW_ONLY mode (print target + calldata for a safe) unless `--broadcast` is among the
# forge args, in which case `--rpc-url base` is added when no --rpc-url is given, e.g.
#   script/notion/run.sh AAPLc schedule --broadcast --account <keystore>
set -euo pipefail

usage() { echo "usage: $0 <Name> <encode|schedule|create> [forge script args...]" >&2; exit 1; }
[ $# -ge 2 ] || usage
NAME=$1; STEP=$2; shift 2

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
ENV_FILE="$HERE/out/$NAME.env"
[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE; run 'yarn notion:export' first" >&2; exit 1; }

set -a
[ -f "$ROOT/.env" ] && . "$ROOT/.env"
. "$ENV_FILE"
set +a
cd "$ROOT"

case "$STEP" in
  encode)
    forge script script/deployments/EncodePeripheryInitData.s.sol "$@"
    echo "peripheryParams written to script/deployments/inputs/$HUB_STRAT_INPUT_SUBDIR/$HUB_STRAT_INPUT_FILENAME"
    ;;
  schedule|create)
    VIEW_ONLY=true; HAS_RPC=false
    for a in "$@"; do
      [ "$a" = "--broadcast" ] && VIEW_ONLY=false
      [ "$a" = "--rpc-url" ] && HAS_RPC=true
    done
    export VIEW_ONLY
    RPC=()
    if [ "$VIEW_ONLY" = false ] && [ "$HAS_RPC" = false ]; then RPC=(--rpc-url base); fi
    SCRIPT=ScheduleCreateMachine; [ "$STEP" = create ] && SCRIPT=CreateMachine
    forge script "script/deployments/$SCRIPT.s.sol" "${RPC[@]}" "$@" -vvvv
    ;;
  *) usage ;;
esac
