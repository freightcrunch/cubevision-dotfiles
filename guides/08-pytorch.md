# 08 — PyTorch on Jetson

Standard PyPI wheels do **not** include CUDA for aarch64. Use NVIDIA's pre-built wheels.

## 1. Dependencies

```bash
sudo apt-get install -y \
    libopenblas-base libopenmpi-dev libomp-dev \
    libjpeg-dev zlib1g-dev libpython3-dev \
    libopenblas-dev libavcodec-dev libavformat-dev libswscale-dev
```

## 2. Install PyTorch (JetPack 6.x / CUDA 12)

Check the latest wheel at: https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048

```bash
# Create venv
python3 -m venv ~/.venvs/torch --system-site-packages
source ~/.venvs/torch/bin/activate

# PyTorch 2.5 for JetPack 6.x
pip install --no-cache-dir \
    https://developer.download.nvidia.com/compute/redist/jp/v61/pytorch/torch-2.5.0a0+872d972e41.nv24.08.17622132-cp310-cp310-linux_aarch64.whl

# Or use the dotfiles installer:
bash pytorch/setup-pytorch-jetson.sh ~/.venvs/torch
```

## 3. Install torchvision (from source)

torchvision must match the PyTorch version:

| PyTorch | torchvision | Branch |
|---------|-------------|--------|
| 2.5     | 0.20        | v0.20.0 |
| 2.4     | 0.19        | v0.19.0 |
| 2.3     | 0.18        | v0.18.0 |

```bash
source ~/.venvs/torch/bin/activate
pip install Pillow

git clone --branch v0.20.0 https://github.com/pytorch/vision torchvision
cd torchvision
export BUILD_VERSION=0.20.0
python setup.py install
cd ..
```

## 4. Verify

```python
import torch
print(f"PyTorch:       {torch.__version__}")
print(f"CUDA avail:    {torch.cuda.is_available()}")
print(f"CUDA version:  {torch.version.cuda}")
print(f"cuDNN version: {torch.backends.cudnn.version()}")
print(f"Device:        {torch.cuda.get_device_name(0)}")

# Quick GPU test
a = torch.cuda.FloatTensor(2).zero_()
b = torch.randn(2).cuda()
print(f"a + b = {a + b}")
```

```python
import torchvision
print(f"torchvision: {torchvision.__version__}")

from torchvision.models import resnet50
m = resnet50(weights=None).cuda().eval()
x = torch.randn(1, 3, 224, 224).cuda()
with torch.no_grad():
    out = m(x)
print(f"ResNet50 output shape: {out.shape}")
```

## 5. Docker Alternative

```bash
docker run --rm -it --runtime nvidia \
    nvcr.io/nvidia/l4t-pytorch:r36.4.0-pth2.5-py3 \
    python3 -c "import torch; print(torch.cuda.is_available())"
```
