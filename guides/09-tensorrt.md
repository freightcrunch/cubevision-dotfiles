# 09 — TensorRT

TensorRT is pre-installed with JetPack. It accelerates inference on Jetson GPUs.

## 1. Verify

```bash
dpkg -l | grep tensorrt
python3 -c "import tensorrt; print(tensorrt.__version__)"
```

## 2. Convert ONNX → TensorRT Engine

```bash
# Using trtexec (built-in tool)
/usr/src/tensorrt/bin/trtexec \
    --onnx=model.onnx \
    --saveEngine=model.engine \
    --fp16 \
    --workspace=2048
```

Common flags:

| Flag | Description |
|------|-------------|
| `--onnx` | Input ONNX model |
| `--saveEngine` | Output TensorRT engine |
| `--fp16` | Enable FP16 (recommended on Jetson) |
| `--int8` | Enable INT8 quantization |
| `--workspace=N` | Max workspace in MB |
| `--batch=N` | Explicit batch size |
| `--verbose` | Detailed build logs |

## 3. Benchmark a Model

```bash
/usr/src/tensorrt/bin/trtexec \
    --loadEngine=model.engine \
    --batch=1 \
    --iterations=100 \
    --warmUp=500
```

## 4. Python Inference

```python
import tensorrt as trt
import pycuda.driver as cuda
import pycuda.autoinit
import numpy as np

TRT_LOGGER = trt.Logger(trt.Logger.WARNING)

# Load engine
with open("model.engine", "rb") as f:
    runtime = trt.Runtime(TRT_LOGGER)
    engine = runtime.deserialize_cuda_engine(f.read())

context = engine.create_execution_context()

# Allocate buffers
input_shape = engine.get_tensor_shape(engine.get_tensor_name(0))
output_shape = engine.get_tensor_shape(engine.get_tensor_name(1))

h_input = np.random.randn(*input_shape).astype(np.float32)
h_output = np.empty(output_shape, dtype=np.float32)

d_input = cuda.mem_alloc(h_input.nbytes)
d_output = cuda.mem_alloc(h_output.nbytes)

stream = cuda.Stream()

# Inference
cuda.memcpy_htod_async(d_input, h_input, stream)
context.execute_async_v2(
    bindings=[int(d_input), int(d_output)],
    stream_handle=stream.handle
)
cuda.memcpy_dtoh_async(h_output, d_output, stream)
stream.synchronize()

print(f"Output shape: {h_output.shape}")
```

## 5. PyTorch → TensorRT (torch-tensorrt)

```bash
pip install torch-tensorrt
```

```python
import torch
import torch_tensorrt

model = ...  # your PyTorch model
model.eval().cuda()

inputs = [torch_tensorrt.Input(shape=[1, 3, 224, 224], dtype=torch.float16)]
trt_model = torch_tensorrt.compile(model, inputs=inputs, enabled_precisions={torch.float16})

x = torch.randn(1, 3, 224, 224).half().cuda()
result = trt_model(x)
```

## 6. TensorRT Samples

```bash
cd /usr/src/tensorrt/samples/
ls
# sampleOnnxMNIST, sampleINT8, etc.
cd sampleOnnxMNIST && make && ../../bin/sample_onnx_mnist
```
