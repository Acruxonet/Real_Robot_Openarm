#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

MODE="train"
if [[ "${1:-}" == "--smoke" ]]; then
    MODE="smoke"
    shift
fi

if [[ "$#" -ne 0 ]]; then
    echo "Usage: $0 [--smoke]" >&2
    exit 2
fi

if [[ "${MODE}" == "smoke" ]]; then
    SESSION="pi05_openarm_smoke_${TIMESTAMP}"
    TRAIN_OVERRIDES=(
        --steps=2
        --batch_size=1
        --num_workers=1
        --log_freq=1
        --save_checkpoint=false
    )
else
    SESSION="pi05_openarm_${TIMESTAMP}"
    TRAIN_OVERRIDES=()
fi

OUTPUT_ROOT="${ROOT_DIR}/train/outputs/pi05"
OUTPUT_DIR="${OUTPUT_ROOT}/${SESSION}"
# Keep the launcher log outside OUTPUT_DIR. LeRobot requires OUTPUT_DIR not to
# exist when resume=false and creates it itself after validating the config.
LOG_FILE="${OUTPUT_ROOT}/${SESSION}.log"

source /root/main/applications/miniconda3/etc/profile.d/conda.sh
conda activate real_robot

cd "${ROOT_DIR}"
mkdir -p "${OUTPUT_ROOT}"

printf -v TRAIN_COMMAND '%q ' \
    lerobot-train \
    --config_path=train/pi05/pi05_openarm_20k.yaml \
    --output_dir="${OUTPUT_DIR}" \
    --job_name="${SESSION}" \
    "${TRAIN_OVERRIDES[@]}"

tmux new-session -d -s "${SESSION}" -c "${ROOT_DIR}" \
    "${TRAIN_COMMAND} 2>&1 | tee -a '${LOG_FILE}'"

echo "Started ${MODE} run in tmux session: ${SESSION}"
echo "Attach with: tmux attach -t ${SESSION}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Log file: ${LOG_FILE}"
