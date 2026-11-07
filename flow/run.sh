#!/usr/bin/env bash
# Runs OpenROAD-flow-scripts on rv32i_soc inside the openroad/orfs Docker image.
#
# Usage, from WSL:
#   flow/run.sh                  # synthesis only (default target: synth)
#   flow/run.sh floorplan        # any ORFS target: synth floorplan place cts route finish
#   flow/run.sh gui_floorplan    # open a finished stage in the OpenROAD GUI (via WSLg)
#   flow/run.sh images floorplan # save PNGs of a finished stage to $ORFS_WORK/images
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

if [ "${1:-}" = images ]; then
    STAGE=${2:?usage: flow/run.sh images floorplan|place|cts|route|final}
    case $STAGE in
        floorplan) ODB=2_floorplan.odb ;;
        place)     ODB=3_place.odb ;;
        cts)       ODB=4_cts.odb ;;
        route)     ODB=5_route.odb ;;
        final)     ODB=6_final.odb ;;
        *) echo "unknown stage: $STAGE" >&2; exit 1 ;;
    esac
    mkdir -p "$WORK/images"
    exec docker run "${DOCKER_ARGS[@]}" -e QT_QPA_PLATFORM=offscreen -e STAGE="$STAGE" \
        -e ODB_FILE="/work_out/results/sky130hd/rv32i_soc/base/$ODB" -e IMAGE_DIR=/work_out/images \
        "$IMAGE" bash -c "
        source /OpenROAD-flow-scripts/env.sh >/dev/null &&
        openroad -gui -no_splash -exit /work/flow/save_images.tcl"
fi

exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" bash -c "
    source /OpenROAD-flow-scripts/env.sh >/dev/null &&
    make -C /OpenROAD-flow-scripts/flow DESIGN_CONFIG=/work/flow/config.mk WORK_HOME=/work_out $TARGETS"
