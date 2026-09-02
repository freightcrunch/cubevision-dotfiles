# 07 — Camera (CSI & USB)

## 1. CSI Camera (e.g. IMX219, IMX477)

### Enable CSI Overlay (Required First-Time Setup)

Jetson Orin does **not** create `/dev/video*` nodes for CSI cameras by default.
You must enable the correct device tree overlay, then reboot:

```bash
sudo /opt/nvidia/jetson-io/jetson-io.py
```

- Select **Configure Jetson 24pin CSI Connector**
- Choose the matching overlay (e.g. **Camera IMX219 Dual** for 2× IMX219)
- Save, exit, and **reboot**

After reboot, verify the overlay is active:

```bash
sudo cat /proc/device-tree/nvidia,dtbbuildtime 2>/dev/null
dmesg | grep -i imx
```

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

- **No /dev/video* (CSI)**: Device tree overlay not loaded — run `sudo /opt/nvidia/jetson-io/jetson-io.py`, enable the correct camera overlay, and reboot. Verify with `dmesg | grep -iE 'imx|csi|vi '`
- **Only /dev/media0, no /dev/video***: Tegra VI driver loaded but no sensor bound. Check connector seating, ribbon cable orientation (contacts face the board), and that the overlay matches your sensor
- **nvarguscamerasrc not found**: `sudo apt install nvidia-l4t-gstreamer`
- **Camera busy**: Another process may hold the device. Check `fuser /dev/video0`
- **Arducam-specific**: Some Arducam boards need their own driver/overlay. Check [arducam.com/docs](https://docs.arducam.com) for Jetson Orin instructions
