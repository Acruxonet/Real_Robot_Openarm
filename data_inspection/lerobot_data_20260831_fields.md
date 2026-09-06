# LeRobot 数据集字段说明

本文档总结 `lerobot_data_20260831` 的字段、数据类型、形状和图像格式。字段定义来自
`meta/info.json`，数值统计来自 `meta/stats.json`；视频分辨率另外从全部 MP4 视频轨道核查。

## 数据集概览

| 项目 | 值 |
| --- | --- |
| LeRobot codebase version | `v3.0` |
| 机器人类型 | `moqi_openarm` |
| Episode 数量 | `148` |
| 总帧数 | `107821` |
| 任务数量 | `1` |
| 数据频率 | `30 Hz` |
| 数据划分 | `train: 0:148` |
| Parquet 数据 | 约 `1000 MB` |
| 视频数据 | 约 `6000 MB` |
| 数据文件模板 | `data/chunk-{chunk_index:03d}/file-{file_index:03d}.parquet` |
| 视频文件模板 | `videos/{video_key}/chunk-{chunk_index:03d}/file-{file_index:03d}.mp4` |

当前任务文本位于 `meta/tasks.parquet`，内容为：

```text
Pass the black bottle from the right hand to the left, then place it into the white box.
```

## 字段总表

| 字段 | metadata dtype | shape | 数据频率 | 含义 |
| --- | --- | --- | --- | --- |
| `action` | `float32` | `[16]` | 30 Hz | 双臂动作向量 |
| `observation.state` | `float32` | `[16]` | 30 Hz | 双臂当前状态向量 |
| `observation.images.left` | `video` | `[480, 640, 3]` | 30 Hz | 左侧相机 RGB 视频帧 |
| `observation.images.right` | `video` | `[480, 640, 3]` | 30 Hz | 右侧相机 RGB 视频帧 |
| `observation.images.head` | `video` | metadata `[720, 1280, 3]`; MP4 实测 `[960, 1280, 3]` | 30 Hz | 头部/全局相机 RGB 视频帧 |
| `timestamp` | `float32` | `[1]` | 30 Hz | 当前帧时间戳，单位为秒 |
| `frame_index` | `int64` | `[1]` | 30 Hz | 当前 episode 内的帧编号 |
| `episode_index` | `int64` | `[1]` | 30 Hz | episode 编号，范围为 `0..147` |
| `index` | `int64` | `[1]` | 30 Hz | 数据集全局帧编号，范围为 `0..107820` |
| `task_index` | `int64` | `[1]` | 30 Hz | 任务编号；本数据集只有任务 `0` |

说明：`shape` 是 metadata 对字段的声明。数字字段通常从 Parquet 读取为对应的
PyTorch tensor；视频字段需要从 MP4 解码后才能作为图像 tensor 使用。

从实际 Parquet schema 看，`data/chunk-000/file-000.parquet` 的字段类型为：

```text
action             list<float>   # 每行长度 16，元素为单精度浮点数
observation.state  list<float>   # 每行长度 16，元素为单精度浮点数
timestamp          float32
frame_index        int64
episode_index      int64
index              int64
task_index         int64
```

三路图像不是 Parquet 中的数值列，而是根据 episode metadata 中的路径从对应 MP4
文件读取。`meta/tasks.parquet` 另外包含：

```text
task_index  int64
task        string
```

`meta/episodes/chunk-000/file-000.parquet` 是 episode 级索引，包含 episode 编号、数据
行范围、每路视频的文件编号和起止时间戳、任务列表、episode 长度，以及各字段的
episode-level `min/max/mean/std/count` 统计；它不是 policy 的逐帧 observation 输入。

## `action`

`action` 是一个长度为 16 的 `float32` 向量，数据频率为 30 Hz。字段顺序必须保持如下：

| 位置 | 名称 | 说明 |
| ---: | --- | --- |
| 0 | `qpos_0_0` | 第 0 组机械臂关节 0 |
| 1 | `qpos_0_1` | 第 0 组机械臂关节 1 |
| 2 | `qpos_0_2` | 第 0 组机械臂关节 2 |
| 3 | `qpos_0_3` | 第 0 组机械臂关节 3 |
| 4 | `qpos_0_4` | 第 0 组机械臂关节 4 |
| 5 | `qpos_0_5` | 第 0 组机械臂关节 5 |
| 6 | `qpos_0_6` | 第 0 组机械臂关节 6 |
| 7 | `gripper_0` | 第 0 组机械臂夹爪 |
| 8 | `qpos_1_0` | 第 1 组机械臂关节 0 |
| 9 | `qpos_1_1` | 第 1 组机械臂关节 1 |
| 10 | `qpos_1_2` | 第 1 组机械臂关节 2 |
| 11 | `qpos_1_3` | 第 1 组机械臂关节 3 |
| 12 | `qpos_1_4` | 第 1 组机械臂关节 4 |
| 13 | `qpos_1_5` | 第 1 组机械臂关节 5 |
| 14 | `qpos_1_6` | 第 1 组机械臂关节 6 |
| 15 | `gripper_1` | 第 1 组机械臂夹爪 |

根据 `meta/stats.json`，每个 action 维度都有独立的 `min`、`max`、`mean`、`std` 和
`count` 统计，所有维度的 `count` 都是 `107821`。统计中的 action 最小值和最大值如下，
可用于检查训练或部署时的反归一化结果：

```text
min = [
  -1.273608, -1.388672, -1.298459,  0.543523, -1.349745, -0.785495, -1.570884, -0.900000,
  -1.214759,  0.013880, -0.899893,  0.543523, -0.478676, -0.785306, -0.605740, -0.900000
]
max = [
   1.396076,  0.135578,  1.529092,  2.393258,  0.145975,  0.484658,  0.551207,  0.050000,
   0.918833,  1.075584,  0.324230,  2.126822,  1.354801,  0.784672,  1.570879,  0.050000
]
```

这里的 `qpos_*` 和 `gripper_*` 单位没有在 LeRobot metadata 中声明，实际单位和控制
语义应以 OpenArm 采集端/驱动端定义为准。尤其不能假设两个 gripper 字段天然处于
`[0, 1]`。

## `observation.state`

`observation.state` 同样是长度为 16 的 `float32` 向量，频率为 30 Hz，字段顺序与
`action` 完全相同：

```text
[
  qpos_0_0, qpos_0_1, qpos_0_2, qpos_0_3, qpos_0_4, qpos_0_5, qpos_0_6, gripper_0,
  qpos_1_0, qpos_1_1, qpos_1_2, qpos_1_3, qpos_1_4, qpos_1_5, qpos_1_6, gripper_1
]
```

`meta/stats.json` 中 state 的逐维范围为：

```text
min = [
  -1.247234, -1.374266, -1.316281,  0.510987, -1.360914, -0.815023, -1.635958, -1.157206,
  -1.239605,  0.007439, -0.908103,  0.504502, -0.486954, -0.793278, -0.663195, -1.257153
]
max = [
   1.424620,  0.119211,  1.541733,  2.425231,  0.143244,  0.499161,  0.563630, -0.374419,
   0.903525,  1.089303,  0.333982,  2.114328,  1.351377,  0.784123,  1.611543,  0.066567
]
```

## 三路图像

### `observation.images.left`

- metadata dtype：`video`
- 单帧 shape：`[height, width, channels] = [480, 640, 3]`
- 语义：左侧相机 RGB 图像
- 存储：MP4 视频，AV1 codec，`yuv420p` pixel format
- 视频帧率：30 Hz
- 音频：无
- 深度图：否

### `observation.images.right`

- metadata dtype：`video`
- 单帧 shape：`[480, 640, 3]`
- 语义：右侧相机 RGB 图像
- 存储：MP4 视频，AV1 codec，`yuv420p` pixel format
- 视频帧率：30 Hz
- 音频：无
- 深度图：否

### `observation.images.head`

- metadata dtype：`video`
- metadata 声明：`[720, 1280, 3]`
- MP4 实测单帧 shape：`[960, 1280, 3]`
- 语义：头部/全局相机 RGB 图像
- 存储：MP4 视频，AV1 codec，`yuv420p` pixel format
- 视频帧率：30 Hz
- 音频：无
- 深度图：否

视频轨道核查覆盖 148 个 episode 文件：`left` 和 `right` 均为 `640x480`，`head`
均为 `1280x960`。因此 head 的 `720` 是 metadata 错误，不是视频实际分辨率；读取和
预处理应以 MP4 实际帧为准。

### 图像读取时的 dtype

`info.json` 中的 `video` 是文件存储类型，不是 `float32` 或 `uint8` 的数值 dtype。按
当前 LeRobot 解码器的默认行为：

- 原始视频文件中保存的是压缩视频帧，不是直接保存的 float 数组；
- 默认解码结果是 `torch.Tensor`，shape 为 `[N, C, H, W]`，dtype 为 `float32`，数值范围
  为 `[0, 1]`；单帧通常为 `[C, H, W]`；
- 设置 `return_uint8=True` 时，解码结果为 `uint8`，shape 仍为 `[N, C, H, W]`，数值范围
  为 `[0, 255]`；
- `meta/stats.json` 中三路图像的 min/max 也显示为每个通道 `0.0..1.0`，与默认
  float32 解码后的统计口径一致。

在 LeRobot 的默认数据读取流程中，图像通常已经被解码为 `torch.Tensor`；如果直接查看
原始相机/环境接口，常见输入仍是 HWC、`uint8`、`0..255` 的 RGB 数组，之后由数据集
读取器或 policy processor 转换为模型所需的 CHW、`float32` 格式。

因此，训练和部署时应让相机输入经过与 policy processor 一致的 resize、通道排列和
归一化流程，不能仅根据 MP4 的编码格式直接构造模型输入。

## 时间和索引字段

| 字段 | dtype | shape | 范围/含义 |
| --- | --- | --- | --- |
| `timestamp` | `float32` | `[1]` | 秒；统计范围约为 `0.0..34.6` |
| `frame_index` | `int64` | `[1]` | episode 内帧编号；统计最大值为 `1038` |
| `episode_index` | `int64` | `[1]` | episode 编号；`0..147` |
| `index` | `int64` | `[1]` | 全局帧编号；`0..107820` |
| `task_index` | `int64` | `[1]` | 任务编号；本数据集所有帧均为 `0` |

这些字段主要用于对齐 Parquet 行、视频帧、episode 和任务，不应作为普通机器人状态
直接输入 policy，除非训练配置明确这样做。

## 当前数据的注意事项

1. `action` 和 `observation.state` 都是 16 维，但二者的统计范围并不完全相同；训练时
   应使用 policy processor 保存的统计量进行归一化。
2. 数据只有一个 `train` split，没有在 metadata 中提供独立 validation/test split。
3. 三路相机的视角和字段名是 policy 输入契约的一部分。部署到 OpenArm 时，实时相机
   必须映射为相同的 `left`、`right`、`head` 语义。
4. metadata 没有声明关节角/夹爪的物理单位、左右臂编号映射或底层控制模式；这些信息
   需要从 OpenArm 驱动和数据采集代码补充，不能从本文件推断。
