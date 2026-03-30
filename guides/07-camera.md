# 07 — Camera (CSI & USB)

## 1. CSI Camera (e.g. IMX219, IMX477)

### Detect

```bash
ls /dev/video*
v4l2-ctl --list-devices
```

### GStreamer Pipeline — Preview

```bash
# IMX219 (Raspberry Pi Camera v2)
gst-launch-1.0 nvarguscamerasrc sensor-id=0 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvvidconv ! nv3dsink
```

### GStreamer → OpenCV

```python
import cv2

pipeline = (
    "nvarguscamerasrc sensor-id=0 ! "
    "video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1 ! "
    "nvvidconv ! video/x-raw,format=BGRx ! "
    "videoconvert ! video/x-raw,format=BGR ! "
    "appsink drop=1"
)

cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    cv2.imshow("CSI Camera", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
```

## 2. USB Camera

### Detect

```bash
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --list-formats-ext
```

### GStreamer Pipeline

```bash
gst-launch-1.0 v4l2src device=/dev/video0 ! \
    video/x-raw,width=640,height=480,framerate=30/1 ! \
    videoconvert ! nv3dsink
```

### OpenCV (V4L2)

```python
import cv2

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    cv2.imshow("USB Camera", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
```

## 3. Save to File

```bash
# CSI → H.264 MP4
gst-launch-1.0 nvarguscamerasrc num-buffers=300 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvv4l2h264enc bitrate=8000000 ! h264parse ! \
    mp4mux ! filesink location=output.mp4

# USB → JPEG snapshots
gst-launch-1.0 v4l2src device=/dev/video0 num-buffers=1 ! \
    jpegenc ! filesink location=snapshot.jpg
```

## Troubleshooting

- **No /dev/video***: Check cable, run `sudo dmesg | tail -20`
- **nvarguscamerasrc not found**: `sudo apt install nvidia-l4t-gstreamer`
- **Camera busy**: Another process may hold the device. Check `fuser /dev/video0`
