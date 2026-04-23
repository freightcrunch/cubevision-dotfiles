# 04 — jtop Monitoring

[jetson-stats](https://github.com/rbonghi/jetson_stats) provides `jtop`, a top-like tool for Jetson hardware monitoring.

## 1. Install

```bash
sudo pip3 install -U jetson-stats
sudo systemctl restart jtop.service
```

## 2. Usage

```bash
jtop
```

Navigate tabs with arrow keys:

| Tab | Shows |
|-----|-------|
| 1 GPU | GPU utilization, frequency, temperature |
| 2 CPU | Per-core usage, frequency |
| 3 MEM | RAM, swap, EMC usage |
| 4 ENG | Hardware engines (NVDEC, NVJPG, etc.) |
| 5 CTRL | Power mode, fan speed, jetson_clocks |
| 6 INFO | JetPack version, L4T, CUDA, cuDNN, TensorRT |

## 3. Programmatic Access

```python
from jtop import jtop

with jtop() as j:
    print(f"GPU:  {j.gpu['val']}%")
    print(f"RAM:  {j.ram['use']} / {j.ram['tot']} MB")
    print(f"Temp: {j.temperature['CPU']}°C")
    print(f"Power: {j.power['tot']['cur']} mW")
```

## 4. Verify JetPack Components

In jtop, press right arrow to reach the **INFO** tab. Confirm:

- **JetPack**: 6.2+
- **L4T**: 36.5+
- **CUDA**: 12.6+
- **cuDNN**: 9.x
- **TensorRT**: 10.x
- **OpenCV**: 4.x (with CUDA)

## 5. Patch — JetPack "Not Installed" Fix

If the INFO tab shows **JetPack: Not installed** despite `dpkg -l nvidia-jetpack`
confirming it is present, the installed jetson-stats version is missing your L4T
release from its lookup table. Apply the patch:

```bash
sudo bash ~/work/CascadeProjects/dotfiles/scripts/patch-jtop-jetpack.sh
```

The script is idempotent — safe to re-run after `pip3 install -U jetson-stats`.
To add future L4T versions, edit the `PATCHES` map in the script.

## 6. Alias

Already in dotfiles `.zshrc`:

```bash
alias jtop='sudo jtop'
```
