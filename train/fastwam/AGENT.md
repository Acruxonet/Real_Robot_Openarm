# FastWAM shared-machine setup

This directory launches FastWAM training for the OpenArm LeRobot dataset. Run
all commands from a shell on the GPU machine. `run.sh` finds the repository root
relative to itself, so the repository may live at any absolute path.

## Required machine setup

- Linux, `bash`, `tmux`, Git, and a working NVIDIA driver.
- A CUDA-capable PyTorch build. The intended machine is a large-memory GPU;
  training starts with `batch_size: 1` because FastWAM contains a roughly 5B
  Wan video expert.
- Conda (Miniconda or Anaconda) and a dedicated environment.
- The OpenArm dataset in LeRobot v3 format, including `meta/`, `data/`, and
  `videos/`. The dataset must expose the three camera keys `left`, `right`, and
  `head`, plus 16-dimensional `observation.state` and `action`.
- Enough shared-disk space for the dataset, Hugging Face models, checkpoints,
  logs, and temporary files. FastWAM uses several large model repositories.

Install the repository's LeRobot checkout into the environment:

```bash
conda create -n real_robot python=3.12 -y
conda activate real_robot
cd /path/to/real_robot/lerobot
python -m pip install -e ".[training,fastwam]"
```

Verify the environment before training:

```bash
python -c 'import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))'
command -v lerobot-train
command -v tmux
```

## Environment variables

Put machine-specific values in the launching shell or in a private setup file
outside Git. Do not commit access tokens.

```bash
# Required when Conda is not installed at the default path used on the original machine.
export CONDA_SH=/shared/apps/miniconda3/etc/profile.d/conda.sh
export CONDA_ENV=real_robot

# Required when the dataset is not inside the repository at lerobot_data_20260831.
export FASTWAM_DATASET_ROOT=/shared/datasets/lerobot_data_20260831

# Recommended: checkpoints and launcher logs on the large shared disk.
export FASTWAM_OUTPUT_ROOT=/shared/experiments/real_robot/fastwam

# Recommended: keep all Hugging Face downloads on the large shared disk.
# HF_HOME is the main setting; Hugging Face derives its hub cache beneath it.
export HF_HOME=/shared/cache/huggingface
export HF_HUB_CACHE="$HF_HOME/hub"

# Required only for gated/private repositories or to avoid anonymous rate limits.
# Obtain the token interactively or from the machine's secret manager.
export HF_TOKEN='YOUR_PRIVATE_TOKEN'

# Recommended for torchvision/PyTorch downloads and temporary decoder files.
export TORCH_HOME=/shared/cache/torch
export TMPDIR=/shared/tmp/real_robot_fastwam

# Optional: select one GPU. tmux inherits this value when run.sh starts.
export CUDA_VISIBLE_DEVICES=0

# Optional W&B settings. The YAML enables W&B by default.
export WANDB_DIR=/shared/experiments/real_robot/wandb
export WANDB_PROJECT=openarm-policy
# Use this on a machine that must not contact W&B:
# export WANDB_MODE=offline
```

Create writable directories before launching:

```bash
mkdir -p "$FASTWAM_OUTPUT_ROOT" "$HF_HOME" "$HF_HUB_CACHE" \
  "$TORCH_HOME" "$TMPDIR" "$WANDB_DIR"
```

`TRANSFORMERS_CACHE` is intentionally not needed; current Hugging Face libraries
use `HF_HOME`/`HF_HUB_CACHE`. Set `HF_HUB_OFFLINE=1` only after every required
model is present in the cache. Otherwise the first run must have network access.

The required model repositories are:

- `lerobot/fastwam_base`
- `Wan-AI/Wan2.2-TI2V-5B`
- `Wan-AI/Wan2.2-TI2V-5B-Diffusers`
- `google/umt5-xxl`

If several machines share `HF_HOME`, make sure the directory is writable by all
training users. Let one process finish the initial downloads before starting
multiple jobs, especially on a network filesystem.

## Launch

First run the two-step smoke test. It still constructs the model and may perform
the initial model downloads, so it is not necessarily quick:

```bash
cd /path/to/real_robot
train/fastwam/run.sh --smoke
```

Inspect the tmux session and log path printed by the launcher. If the smoke test
completes without CUDA OOM, missing-model, video-decoder, or dataset-key errors,
start the full run:

```bash
train/fastwam/run.sh
```

Useful commands:

```bash
tmux ls
tmux attach -t fastwam_openarm_<timestamp>
tail -f "$FASTWAM_OUTPUT_ROOT/fastwam_openarm_<timestamp>.log"
```

## Important configuration facts

- `run.sh` overrides `dataset.root` and `output_dir` using the environment
  variables above; no YAML edit is needed when moving machines.
- The YAML explicitly sets both `pretrained_path: lerobot/fastwam_base` and
  `base_model_id: lerobot/fastwam_base`. `pretrained_path` triggers loading the
  released LeRobot policy weights; `base_model_id` records the intended base
  initialization. The FastWAM loader uses non-strict, shape-aware loading for
  the OpenArm 16-dimensional action/proprioception heads.
- The YAML expects three camera views, each resized by FastWAM to `224 x 224`.
  Their concatenated model size is `[224, 672]`.
- The policy expects 16 state channels and 16 action channels.
- `num_video_frames: 33` and `action_video_freq_ratio: 4` produce nine model
  frames and satisfy the Wan VAE temporal constraint.
- Gradient checkpointing is enabled. If batch size 1 still runs out of memory,
  do not reduce it further; use a larger GPU, distributed/FSDP training, or set
  `freeze_video_expert: true` together with `loss.lambda_video: 0` after deciding
  that action-expert-only fine-tuning is acceptable.

## Common failures

- **Conda script not found:** correct `CONDA_SH`.
- **`lerobot-train` not found:** activate `CONDA_ENV` and install the local
  `lerobot` checkout with the `training,fastwam` extras.
- **401/403 from Hugging Face:** accept any applicable model terms and provide
  a valid `HF_TOKEN`.
- **No space left / cache under the home directory:** verify `HF_HOME`,
  `HF_HUB_CACHE`, `TORCH_HOME`, `TMPDIR`, and `FASTWAM_OUTPUT_ROOT` before launch.
- **CUDA unavailable:** check the driver with `nvidia-smi`, then verify that the
  environment's PyTorch build matches the machine's supported CUDA stack.
- **W&B login failure:** run `wandb login`, provide `WANDB_API_KEY` through a
  secret manager, or set `WANDB_MODE=offline`.
