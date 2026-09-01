# OpenArm Policy Training

This repository is for training and deploying policies on an OpenArm robot. The
current dataset is a 30 Hz, bimanual bottle pick-and-place dataset. The planned
comparison contains four LeRobot policies:

| Policy | LeRobot type | Local source | Current status |
| --- | --- | --- | --- |
| ACT | `act` | [`policy/act`](policy/act) | Training entry point available |
| Diffusion Policy | `diffusion` | [`policy/dp`](policy/dp) | Training config/entry point pending |
| PI05 | `pi05` | [`policy/pi05`](policy/pi05) | Training config/entry point pending |
| FastWAM | `fastwam` | [`policy/fastwam`](policy/fastwam) | Training config/entry point pending |

The repository must not be considered complete for the four-policy experiment
until the three pending training configurations have been added and each policy
has passed a one-step dataset and forward-pass smoke test.

## Dataset

The local dataset is:

```text
/mnt/data/nas/hufangchi/projects/real_robot/lerobot_data_20260831
```

Its main properties are:

| Property | Value |
| --- | --- |
| Episodes | 148 |
| Frames | 107,821 |
| Frequency | 30 Hz |
| Task count | 1 |
| State | `float32`, shape `[16]` |
| Action | `float32`, shape `[16]` |
| Cameras | `left`, `right`, `head` |
| Native camera shapes | left/right `[480, 640, 3]`; head `[720, 1280, 3]` |

The complete field and metadata inspection is in
[`data_inspection/lerobot_data_20260831_fields.md`](data_inspection/lerobot_data_20260831_fields.md).
The dataset is read-only and must not be modified by training.

The 16 action/state entries are ordered as seven joints plus one gripper for
each arm:

```text
qpos_0_0 ... qpos_0_6, gripper_0,
qpos_1_0 ... qpos_1_6, gripper_1
```

The dataset metadata does not declare the physical unit or low-level control
semantics of the grippers. Keep the action ordering unchanged and verify the
OpenArm driver convention before deployment. Dataset statistics are used by the
official LeRobot normalizer; the raw dataset is not pre-normalized in place.

## Training pipeline

The intended data path is:

```text
LeRobotDataset
    -> optional per-frame image transform
    -> official LeRobot dataset factory
    -> official LeRobot policy preprocessor
    -> official LeRobot trainer
```

Only geometry-specific preprocessing belongs in this repository. YAML parsing,
dataset splitting, dataloaders, normalization, optimizer setup, mixed precision,
checkpointing, and the training loop belong to the official LeRobot trainer.

### Image contract

The dataset reader returns RGB video frames as channel-first tensors. The custom
ACT transform in [`train/act/letterbox.py`](train/act/letterbox.py) preserves
aspect ratio, resizes, and pads to `[3, 240, 320]`. It returns `uint8` values in
`[0, 255]`; the newer LeRobot trainer then performs its normal `/255` conversion.
This keeps the official preprocessing path unchanged.

ACT requires all visual input features to have the same shape, so all three
cameras use this letterboxed shape for the ACT configuration. The raw MP4 files
and metadata remain unchanged.

The current letterbox callable accepts one frame with shape `[3, H, W]`. A
multi-frame policy configuration such as the default DP history (`n_obs_steps=2`)
requires extending it to accept `[T, 3, H, W]` before DP training is enabled.

## Environment

Use Python 3.12 and a LeRobot checkout compatible with the selected policy. The
local `lerobot/` directory is an independent upstream checkout and has its own
Git repository; it is ignored by the root repository.

```bash
conda activate real_robot
cd /mnt/data/nas/hufangchi/projects/real_robot/lerobot
python -m pip install -e ".[training]" \
  --index-url http://mirrors.cloud.aliyuncs.com/pypi/simple/ \
  --trusted-host mirrors.cloud.aliyuncs.com
```

The training extra installs the dataset stack, `accelerate`, and `wandb` in
addition to LeRobot's base dependencies. The PyTorch package must match the
installed NVIDIA driver. Check this before choosing `cuda` in a config:

```bash
python - <<'PY'
import torch
print(torch.__version__)
print(torch.version.cuda)
print(torch.cuda.is_available())
PY
```

If `torch.cuda.is_available()` is `False`, training will not use the H20 even if
the YAML says `device: cuda`; fix the driver/PyTorch pairing first.

## ACT

The newer LeRobot API uses `make_train_eval_datasets(cfg)`. The ACT wrapper
injects the letterbox transform into both datasets and then calls the official
trainer. It does not implement a second training loop.

Configuration: [`train/act/act_openarm.yaml`](train/act/act_openarm.yaml)

Entry point: [`train/act/train_act_new.py`](train/act/train_act_new.py)

Run from the project root:

```bash
conda activate real_robot
cd /mnt/data/nas/hufangchi/projects/real_robot
python train/act/train_act_new.py \
  --config_path=train/act/act_openarm.yaml \
  --output_dir=train/outputs/act_openarm_20260901
```

The output directory must not already exist unless the run is an explicit
resume. Checkpoints under `train/outputs/` are ignored by Git.

Before a long run, use a temporary output directory and one step:

```bash
python train/act/train_act_new.py \
  --config_path=train/act/act_openarm.yaml \
  --steps=1 --batch_size=1 --num_workers=0 \
  --persistent_workers=false --policy.device=cpu \
  --policy.use_amp=false --policy.pretrained_backbone_weights=null \
  --output_dir=/tmp/act_openarm_smoke
```

The smoke test should load the dataset, construct ACT, execute one update, and
write a checkpoint without modifying the dataset.

## Diffusion Policy

Use LeRobot type `diffusion` and the official diffusion trainer. The policy
configuration requires:

- action and state feature shapes of `[16]`;
- all three visual features with one common `[3, H, W]` shape;
- an image transform that supports the policy's temporal image window;
- an explicit `horizon`, `n_obs_steps`, and `n_action_steps` compatible with
  the 30 Hz dataset.

The current DP source defaults to `n_obs_steps=2`, so the single-frame ACT
letterbox function cannot be reused unchanged. Add a DP config and a thin
factory wrapper only after the transform handles both `[3, H, W]` and
`[T, 3, H, W]` inputs.

## PI05

Use LeRobot type `pi05` and the official PI05 trainer. This policy differs from
ACT and DP in several ways:

- visual normalization is identity by default;
- state and action use quantile normalization;
- the state/action vectors are padded internally to `max_state_dim` and
  `max_action_dim` (the dataset itself remains 16-dimensional);
- the task string is tokenized into a PaliGemma prompt;
- the default model image resolution is `224 x 224`.

The task text must be passed through the dataset's `task` field. PI05 also needs
its model/tokenizer dependencies and pretrained weights available locally or
downloadable from the model hub. Add a dedicated config and run a one-batch
processor smoke test before starting a full fine-tune.

## FastWAM

Use LeRobot type `fastwam` and the official FastWAM trainer. FastWAM has a
different image contract from ACT and DP: it resizes camera views inside the
model and concatenates them along width. With three cameras, the configured
total image width must be divisible by 3; for example, three `224 x 224`
cameras correspond to a concatenated image size of `[224, 672]`.

The OpenArm dataset has 16 action channels, so FastWAM must be configured with
`action_dim: 16` and a matching `observation.state` shape if proprioception is
enabled. Its default `action_dim: 7` and default `image_size: [224, 448]` are
not valid for this three-camera, 16-action dataset. FastWAM also requires the
Wan base model, tokenizer, text encoder, and their associated dependencies.

Do not apply ACT's `[240, 320]` letterbox blindly to FastWAM. Configure the
FastWAM model's own camera geometry and verify the concatenated feature widths.

## Checkpoints and deployment

The official trainer writes a checkpoint directory containing the policy model,
configuration, processor metadata, and training state. The deployment artifact
must include the policy weights and the matching preprocessor/postprocessor
configuration, not just a raw `model.safetensors` file.

Before deploying to a real OpenArm:

1. Load the policy with the same LeRobot version used for training.
2. Map the three live cameras to the exact dataset keys `left`, `right`, and
   `head`.
3. Reproduce the policy-specific image geometry and pixel conversion.
4. Confirm state/action ordering, joint units, gripper convention, and action
   limits against the OpenArm driver.
5. Run inference with unnormalization enabled and test at low speed with a
   hardware stop available.

## Repository layout

```text
.
├── data_inspection/          Dataset field and metadata notes
├── policy/                   Vendored policy source snapshots
├── train/act/                ACT config, letterbox, and new-API wrapper
├── lerobot/                  Independent upstream LeRobot checkout (ignored)
└── README.md                 This project guide
```

`policy/` is useful for source inspection and version comparison. Runtime
registration should come from the installed LeRobot package; importing both a
vendored policy and the same installed policy in one process can cause duplicate
configuration registration.
