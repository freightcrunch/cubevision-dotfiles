# 03 — CUDA & cuDNN Verification

CUDA and cuDNN come pre-installed with JetPack. Verify they work.

## 1. Check Versions

```bash
# CUDA
nvcc --version
cat /usr/local/cuda/version.json

# cuDNN
dpkg -l | grep cudnn
cat /usr/include/cudnn_version.h | grep CUDNN_MAJOR -A 2

# GCC (needed for CUDA samples)
gcc --version

# nvidia-smi equivalent on Jetson
sudo tegrastats
# or use jtop (see 04-jtop.md)
```

## 2. CUDA Environment Variables

Add to `~/.bashrc` or `~/.zshenv`:

```bash
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

## 3. Verify CUDA — deviceQuery

```bash
git clone https://github.com/NVIDIA/cuda-samples.git
cd cuda-samples/Samples/1_Utilities/deviceQuery/
make
./deviceQuery
```

Expected output includes:
```
CUDA Device Query (Runtime API)
  ...
  CUDA Capability Major/Minor version number:    8.7
  ...
Result = PASS
```

## 4. Verify cuDNN — mnistCUDNN

```bash
cp -r /usr/src/cudnn_samples_v9/ ~/cudnn_test/
cd ~/cudnn_test/mnistCUDNN/
sudo apt install -y libfreeimage3 libfreeimage-dev
make clean && make
./mnistCUDNN
```

Expected: `Test passed!`

## 5. Quick Python Check

```python
import subprocess
result = subprocess.run(['nvcc', '--version'], capture_output=True, text=True)
print(result.stdout)
```

## Troubleshooting

- **nvcc not found**: Ensure `/usr/local/cuda/bin` is in `$PATH`
- **cuDNN samples missing**: Install with `sudo apt install libcudnn9-samples`
- **deviceQuery FAIL**: Reboot after JetPack install, check `sudo tegrastats`
