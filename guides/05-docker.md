# 05 — Docker & NVIDIA Container Runtime

Docker with GPU access comes pre-installed on JetPack 6.x.

## 1. Verify

```bash
docker --version
sudo docker info | grep -i runtime
# Should show: nvidia
```

## 2. Add User to Docker Group

```bash
sudo usermod -aG docker $USER
newgrp docker
# Or log out and back in

# Test without sudo
docker run --rm hello-world
```

## 3. Test GPU Access

```bash
docker run --rm --runtime nvidia --gpus all \
    nvcr.io/nvidia/l4t-base:r36.4.0 \
    nvidia-smi 2>/dev/null || \
docker run --rm --runtime nvidia \
    nvcr.io/nvidia/l4t-base:r36.4.0 \
    cat /etc/nv_tegra_release
```

> Note: `nvidia-smi` is not available on Jetson. Use `tegrastats` or `jtop` instead.

## 4. Useful Jetson Docker Images

| Image | Use Case |
|-------|----------|
| `nvcr.io/nvidia/l4t-base:r36.4.0` | Base L4T image |
| `nvcr.io/nvidia/l4t-pytorch:r36.4.0-pth2.5-py3` | PyTorch + CUDA |
| `nvcr.io/nvidia/l4t-tensorrt:r36.4.0` | TensorRT |
| `dustynv/jetson-inference:r36` | Jetson Inference (classification, detection) |
| `dustynv/ollama:r36` | Ollama for Jetson |
| `nvcr.io/nvidia/deepstream:7.1-triton-multiarch` | DeepStream |

Browse all: https://catalog.ngc.nvidia.com/containers?filters=&orderBy=scoreDESC&query=l4t

## 5. Docker Compose with GPU

```yaml
# docker-compose.yml
services:
  app:
    image: nvcr.io/nvidia/l4t-pytorch:r36.4.0-pth2.5-py3
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./:/workspace
    working_dir: /workspace
```

```bash
docker compose up
```

## 6. Move Docker Storage to SSD

If your root partition is small:

```bash
sudo systemctl stop docker
sudo mv /var/lib/docker /mnt/ssd/docker
sudo ln -s /mnt/ssd/docker /var/lib/docker
sudo systemctl start docker
```

## 7. Prune Unused Images

```bash
docker system prune -a
```
