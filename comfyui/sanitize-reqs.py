#!/usr/bin/env python3
"""Strip GPU-stack packages from a custom node's requirements.txt.

Node authors routinely pin their own torch/transformers/opencv versions;
installing those would replace the image's locked CUDA stack. Blocked lines
are kept as comments so the build log shows what was skipped. Version
enforcement itself happens via the pip constraints file — this filter is the
belt to that suspender, mirroring the reference installers.
"""
import re
import sys
from pathlib import Path

BLOCKED_PREFIXES = [
    "torch", "torchvision", "torchaudio",
    "xformers", "triton", "sageattention",
    "transformers", "tokenizers", "huggingface-hub", "huggingface_hub",
    "timm", "numpy",
    "opencv-python", "opencv-contrib-python", "opencv-python-headless",
    "cuda-toolkit", "cuda-bindings",
]
BLOCKED_CONTAINS = ["github.com/facebookresearch/sam2"]


def blocked(line: str) -> bool:
    stripped = line.strip().lower()
    if not stripped or stripped.startswith("#"):
        return False
    if stripped.startswith("nvidia-"):
        return True
    if any(item in stripped for item in BLOCKED_CONTAINS):
        return True
    return any(
        re.match(rf"^(-e\s+)?{re.escape(p)}(\[|==|>=|<=|~=|!=|>|<|\s|$)", stripped)
        for p in BLOCKED_PREFIXES
    )


src, dst = Path(sys.argv[1]), Path(sys.argv[2])
out = []
for raw in src.read_text(encoding="utf-8", errors="ignore").splitlines():
    out.append(f"# blocked to protect locked stack: {raw}" if blocked(raw) else raw)
dst.write_text("\n".join(out) + "\n", encoding="utf-8")
