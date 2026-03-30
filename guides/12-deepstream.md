# 12 — DeepStream

NVIDIA DeepStream SDK for video analytics pipelines on Jetson.

## 1. Verify Installation

DeepStream comes with JetPack 6.x:

```bash
deepstream-app --version-all
dpkg -l | grep deepstream
# Typically at /opt/nvidia/deepstream/deepstream
```

If not installed:

```bash
sudo apt install -y \
    deepstream-7.1 \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
```

## 2. Test Sample App

```bash
cd /opt/nvidia/deepstream/deepstream/samples/configs/deepstream-app/

# 4-stream detection demo (file input)
deepstream-app -c source4_1080p_dec_infer-resnet_tracker_sgie_tiled_display_int8.txt
```

## 3. USB Camera Pipeline

Create `ds-usb-camera.txt`:

```ini
[application]
enable-perf-measurement=1
perf-measurement-interval-sec=5

[tiled-display]
enable=1
rows=1
columns=1
width=1280
height=720

[source0]
enable=1
type=1
camera-v4l2-dev-node=0
camera-width=640
camera-height=480
camera-fps-n=30
camera-fps-d=1

[sink0]
enable=1
type=2
sync=0
gpu-id=0

[primary-gie]
enable=1
gpu-id=0
model-engine-file=/opt/nvidia/deepstream/deepstream/samples/models/Primary_Detector/resnet18_trafficcamnet.etlt_b1_gpu0_int8.engine
config-file=/opt/nvidia/deepstream/deepstream/samples/configs/deepstream-app/config_infer_primary.txt

[tracker]
enable=1
tracker-width=640
tracker-height=480
ll-lib-file=/opt/nvidia/deepstream/deepstream/lib/libnvds_nvmultiobjecttracker.so
```

```bash
deepstream-app -c ds-usb-camera.txt
```

## 4. YOLO + DeepStream

Use the [DeepStream-Yolo](https://github.com/marcoslucianops/DeepStream-Yolo) plugin:

```bash
git clone https://github.com/marcoslucianops/DeepStream-Yolo.git
cd DeepStream-Yolo

# Export YOLO to ONNX first
# Then generate engine config for DeepStream
```

## 5. Python Bindings

```bash
pip install pyds
```

```python
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst
Gst.init(None)

# Build pipeline programmatically
pipeline = Gst.parse_launch(
    "filesrc location=sample.mp4 ! qtdemux ! h264parse ! nvv4l2decoder ! "
    "m.sink_0 nvstreammux name=m batch-size=1 width=1920 height=1080 ! "
    "nvinfer config-file-path=config_infer.txt ! "
    "nvvideoconvert ! nvdsosd ! nv3dsink"
)

pipeline.set_state(Gst.State.PLAYING)
```

## 6. Docker

```bash
docker run --rm -it --runtime nvidia \
    --device /dev/video0 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    nvcr.io/nvidia/deepstream:7.1-triton-multiarch
```

## References

- [DeepStream Documentation](https://docs.nvidia.com/metropolis/deepstream/dev-guide/)
- [DeepStream Python Apps](https://github.com/NVIDIA-AI-IOT/deepstream_python_apps)
- [DeepStream-Yolo](https://github.com/marcoslucianops/DeepStream-Yolo)
- [Ultralytics DeepStream Guide](https://docs.ultralytics.com/guides/deepstream-nvidia-jetson/)
