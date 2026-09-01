# LeRobot policies

This directory contains a local, version-pinned copy of four LeRobot policy
implementations for reference and experimentation:

| Local directory | LeRobot policy | Main classes |
| --- | --- | --- |
| `act/` | ACT | `ACTConfig`, `ACTPolicy` |
| `dp/` | Diffusion Policy (DP) | `DiffusionConfig`, `DiffusionPolicy` |
| `pi05/` | PI05 | `PI05Config`, `PI05Policy` |
| `fastwam/` | FastWAM | `FastWAMConfig`, `FastWAMPolicy` |

The small shared files at the directory root (`pretrained.py`, `utils.py`)
and `rtc/` are included because ACT, DP, and PI05 use them through relative
imports. FastWAM also includes its complete `wan/` implementation subpackage.

## Source and version

All four policy directories were copied on **August 31, 2026** from the
installed LeRobot package in:

```text
/root/main/applications/conda_envs/robotwin-lerobot-v060/
```

The source package reports:

```text
LeRobot 0.6.0
Python 3.12
```

The `robocasa` environment currently contains LeRobot `0.3.3`. It provides
ACT and Diffusion, but does not contain PI05 or FastWAM, so it cannot be the
single source for this four-policy snapshot. The four policies are therefore
kept at the same LeRobot `0.6.0` version rather than mixing releases.

The corresponding environment source paths were:

```text
lerobot/policies/act
lerobot/policies/diffusion  ->  policy/dp
lerobot/policies/pi05
lerobot/policies/fastwam
```

The original Apache-2.0 license is included as [`LICENSE`](LICENSE), and the
copyright/license headers in the copied source files are unchanged.

## Important usage note

These are vendored policy source files, not a completely standalone Python
package. The files intentionally retain upstream imports such as
`lerobot.configs`, `lerobot.processor`, and `lerobot.policies.pretrained`. To
run them, use a Python environment containing a compatible LeRobot installation
(preferably LeRobot `0.6.0`) and its optional policy dependencies. The copied
shared files make local relative policy imports visible for source inspection,
but they do not replace the rest of the LeRobot package.

Do not import a local policy module and the same policy from the installed
LeRobot package in one Python process. LeRobot policy configuration classes are
registered globally; loading both copies can raise a duplicate-registration
error. For execution, import from the installed `lerobot` package; use this
directory as the readable source snapshot.

`dp/` is only the local short name requested for Diffusion Policy; the source
file names and class names retain LeRobot's upstream `diffusion` naming.
