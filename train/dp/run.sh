#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

SESSION="dp_openarm_${TIMESTAMP}"

OUTPUT_DIR="${ROOT_DIR}/train/outputs/dp/${SESSION}"
LOG_FILE="${OUTPUT_DIR}/train.log"

source /root/main/applications/miniconda3/etc/profile.d/conda.sh

conda activate real_robot

cd "${ROOT_DIR}"

mkdir -p "${OUTPUT_DIR}"

tmux new-session -d -s "${SESSION}" -c "${ROOT_DIR}" \
    "lerobot-train \
    --config_path=train/dp/dp_openarm.yaml \
    --output_dir='${OUTPUT_DIR}' \
    --job_name=${SESSION} \
    2>&1 | tee -a '${LOG_FILE}'"

echo "Started training in tmux session: ${SESSION}"
echo "Attach with: tmux attach -t ${SESSION}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Log file: ${LOG_FILE}"
