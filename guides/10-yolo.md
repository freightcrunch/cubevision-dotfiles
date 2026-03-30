# 10 — YOLO Deployment on Jetson

## 1. Install Ultralytics

```bash
source ~/.venvs/torch/bin/activate
pip install ultralytics
```

## 2. Export to TensorRT

```python
from ultralytics import YOLO

model = YOLO("yolo11n.pt")  # or yolov8n.pt
model.export(format="engine", half=True, imgsz=640)
# Creates: yolo11n.engine
```

Or via CLI:

```bash
yolo export model=yolo11n.pt format=engine half=True imgsz=640
```

## 3. Run Inference

### Image

```bash
yolo predict model=yolo11n.engine source=image.jpg imgsz=640
```

### USB Camera (live)

```bash
yolo predict model=yolo11n.engine source=0 imgsz=640 show=True
```

### CSI Camera (GStreamer)

```python
from ultralytics import YOLO

model = YOLO("yolo11n.engine")

pipeline = (
    "nvarguscamerasrc sensor-id=0 ! "
    "video/x-raw(memory:NVMM),width=1280,height=720,framerate=30/1 ! "
    "nvvidconv ! video/x-raw,format=BGRx ! "
    "videoconvert ! video/x-raw,format=BGR ! "
    "appsink drop=1"
)

results = model.predict(source=pipeline, show=True, stream=True)
for r in results:
    pass  # results streamed frame by frame
```

### RTSP Stream

```bash
yolo predict model=yolo11n.engine source="rtsp://user:pass@ip:554/stream" show=True
```

## 4. Benchmark

```bash
yolo benchmark model=yolo11n.engine imgsz=640 half=True
```

Expected FPS on Orin Nano SUPER (67 TOPS):

| Model | FP16 FPS (approx) |
|-------|--------------------|
| YOLO11n | ~80-100 |
| YOLO11s | ~50-70 |
| YOLO11m | ~25-35 |
| YOLOv8n | ~90-110 |

## 5. Tasks Beyond Detection

```bash
# Segmentation
yolo predict model=yolo11n-seg.engine source=0 show=True

# Pose estimation
yolo predict model=yolo11n-pose.engine source=0 show=True

# Classification
yolo predict model=yolo11n-cls.engine source=0 show=True
```

## 6. Docker Alternative

```bash
docker run --rm -it --runtime nvidia \
    -v $(pwd):/workspace \
    --device /dev/video0 \
    ultralytics/ultralytics:latest-jetson-jetpack6 \
    yolo predict model=yolo11n.engine source=0 show=True
```

## References

- [Ultralytics Jetson Guide](https://docs.ultralytics.com/guides/nvidia-jetson/)
- [Ultralytics DeepStream Guide](https://docs.ultralytics.com/guides/deepstream-nvidia-jetson/)
