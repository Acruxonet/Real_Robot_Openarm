import torch
import torch.nn.functional as F

TARGET_H, TARGET_W = 240, 320


def letterbox(x):
    _, h, w = x.shape

    scale = min(TARGET_H / h, TARGET_W / w)
    new_h = round(h * scale)
    new_w = round(w * scale)

    # interpolate 需要 float
    x = F.interpolate(
        x.float().unsqueeze(0),
        size=(new_h, new_w),
        mode="bilinear",
        align_corners=False,
        antialias=True,
    ).squeeze(0)

    out = torch.zeros(3, TARGET_H, TARGET_W)
    top = (TARGET_H - new_h) // 2
    left = (TARGET_W - new_w) // 2

    out[:, top:top+new_h, left:left+new_w] = x
    return out.round().clamp(0, 255).to(torch.uint8)
