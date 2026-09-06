#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

# All machine-specific locations can be overridden by the caller. The defaults
# preserve the setup on the machine where this launcher was created.
CONDA_SH="${CONDA_SH:-/root/main/applications/miniconda3/etc/profile.d/conda.sh}"
CONDA_ENV="${CONDA_ENV:-real_robot}"
FASTWAM_DATASET_ROOT="${FASTWAM_DATASET_ROOT:-${ROOT_DIR}/lerobot_data_20260831}"
FASTWAM_OUTPUT_ROOT="${FASTWAM_OUTPUT_ROOT:-${ROOT_DIR}/train/outputs/fastwam}"

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
    SESSION="fastwam_openarm_smoke_${TIMESTAMP}"
    TRAIN_OVERRIDES=(
        --steps=2
        --batch_size=1
        --num_workers=1
        --log_freq=1
        --save_checkpoint=false
        --wandb.enable=false
    )
else
    SESSION="fastwam_openarm_${TIMESTAMP}"
    TRAIN_OVERRIDES=()
fi

OUTPUT_ROOT="${FASTWAM_OUTPUT_ROOT}"
OUTPUT_DIR="${OUTPUT_ROOT}/${SESSION}"
# LeRobot creates OUTPUT_DIR itself after checking that resume is disabled, so
# keep the launcher log in its parent directory.
LOG_FILE="${OUTPUT_ROOT}/${SESSION}.log"

if [[ ! -f "${CONDA_SH}" ]]; then
    echo "Conda initialization script not found: ${CONDA_SH}" >&2
    echo "Set CONDA_SH to <conda-root>/etc/profile.d/conda.sh" >&2
    exit 1
fi
if [[ ! -d "${FASTWAM_DATASET_ROOT}" ]]; then
    echo "Dataset directory not found: ${FASTWAM_DATASET_ROOT}" >&2
    echo "Set FASTWAM_DATASET_ROOT to the LeRobot dataset directory" >&2
    exit 1
fi

source "${CONDA_SH}"
conda activate "${CONDA_ENV}"

cd "${ROOT_DIR}"
mkdir -p "${OUTPUT_ROOT}"

printf -v TRAIN_COMMAND '%q ' \
    lerobot-train \
    --config_path=train/fastwam/fastwam_openarm.yaml \
    --dataset.root="${FASTWAM_DATASET_ROOT}" \
    --output_dir="${OUTPUT_DIR}" \
    --job_name="${SESSION}" \
    "${TRAIN_OVERRIDES[@]}"

tmux new-session -d -s "${SESSION}" -c "${ROOT_DIR}" \
    "${TRAIN_COMMAND} 2>&1 | tee -a '${LOG_FILE}'"

echo "Started ${MODE} run in tmux session: ${SESSION}"
echo "Attach with: tmux attach -t ${SESSION}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Log file: ${LOG_FILE}"
