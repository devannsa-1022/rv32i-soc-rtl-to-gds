#!/usr/bin/env bash
# Runs OpenROAD-flow-scripts on rv32i_soc inside the openroad/orfs Docker image.
#
# Usage, from WSL:
#   flow/run.sh                  # synthesis only (default target: synth)
#   flow/run.sh floorplan        # any ORFS target: synth floorplan place cts route finish
#   flow/run.sh gui_floorplan    # open a finished stage in the OpenROAD GUI (via WSLg)
#   flow/run.sh clean_all        # delete this design's outputs
# From Windows PowerShell:
#   wsl -d Ubuntu --exec bash /mnt/c/.../PD_Project/flow/run.sh synth
#
# The repo is mounted read-only. Logs, reports and results go to $ORFS_WORK
# (default ~/rv32i_orfs_work), under {logs,reports,results}/sky130hd/rv32i_soc/base.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${ORFS_WORK:-$HOME/rv32i_orfs_work}
IMAGE=${ORFS_IMAGE:-openroad/orfs:latest}
TARGETS=${*:-synth}
mkdir -p "$WORK"

DOCKER_ARGS=(--rm -u "$(id -u):$(id -g)" -v "$REPO:/work:ro" -v "$WORK:/work_out")
if [ -t 0 ]; then
    DOCKER_ARGS+=(-it)
fi
if [ -d /mnt/wslg/.X11-unix ]; then
    DOCKER_ARGS+=(-e "DISPLAY=${DISPLAY:-:0}" -v /mnt/wslg/.X11-unix:/tmp/.X11-unix)
fi

exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" bash -c "
    source /OpenROAD-flow-scripts/env.sh >/dev/null &&
    make -C /OpenROAD-flow-scripts/flow DESIGN_CONFIG=/work/flow/config.mk WORK_HOME=/work_out $TARGETS"
