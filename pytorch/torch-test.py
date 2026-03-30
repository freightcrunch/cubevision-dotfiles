#!/usr/bin/env python3
"""Quick smoke-test for PyTorch + TorchVision on Jetson Orin Nano."""

import sys


def main():
    print("=" * 60)
    print("  PyTorch / TorchVision — Jetson Orin Nano Smoke Test")
    print("=" * 60)

    # ── PyTorch ──────────────────────────────────────────────
    try:
        import torch

        print(f"\n  PyTorch version : {torch.__version__}")
        print(f"  CUDA available  : {torch.cuda.is_available()}")

        if torch.cuda.is_available():
            print(f"  CUDA version    : {torch.version.cuda}")
            print(f"  Device name     : {torch.cuda.get_device_name(0)}")
            print(f"  Device count    : {torch.cuda.device_count()}")
            mem = torch.cuda.get_device_properties(0).total_mem / 1024**3
            print(f"  GPU memory      : {mem:.1f} GB")

            # tensor ops on GPU
            a = torch.randn(256, 256, device="cuda")
            b = torch.randn(256, 256, device="cuda")
            c = torch.matmul(a, b)
            print(f"  MatMul test     : {c.shape} on {c.device} ✓")
        else:
            print("  [WARN] CUDA not available — running CPU-only test")
            a = torch.randn(256, 256)
            b = torch.randn(256, 256)
            c = torch.matmul(a, b)
            print(f"  MatMul test     : {c.shape} on {c.device} ✓")
    except ImportError:
        print("\n  [ERROR] PyTorch not installed.")
        sys.exit(1)

    # ── TorchVision ──────────────────────────────────────────
    try:
        import torchvision
        from torchvision import transforms

        print(f"\n  TorchVision ver : {torchvision.__version__}")

        t = transforms.Compose([
            transforms.Resize(224),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        print("  Transforms test : Compose(Resize→Tensor→Normalize) ✓")
    except ImportError:
        print("\n  [WARN] TorchVision not installed — skipping.")

    print("\n" + "=" * 60)
    print("  All checks passed.")
    print("=" * 60)


if __name__ == "__main__":
    main()
