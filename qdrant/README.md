# Qdrant — Vector Database for Jetson

[Qdrant](https://qdrant.tech/) is a high-performance vector similarity search engine.
This directory contains configuration and setup scripts for running Qdrant on the Jetson Orin Nano.

## Quick Start

```bash
# Install and start Qdrant
bash setup-qdrant.sh

# Or run via Docker (NVIDIA runtime)
bash setup-qdrant.sh --docker

# Check status
bash setup-qdrant.sh --status
```

## Endpoints

| Service       | URL                          |
|---------------|------------------------------|
| REST API      | `http://127.0.0.1:6333`     |
| gRPC          | `127.0.0.1:6334`            |
| Dashboard     | `http://127.0.0.1:6333/dashboard` |

## Storage

Default data directory: `~/.local/share/qdrant/storage`

## Configuration

Edit `config.yaml` to tune:
- **Storage**: on-disk vs in-memory indexes
- **Performance**: optimizers, indexing thresholds
- **Limits**: max collection size, payload limits

On the Jetson (8 GB RAM), the config defaults to **on-disk** storage with
memory-mapped indexes to keep RAM usage low.

## Python Client

```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient

client = QdrantClient(host="127.0.0.1", port=6333)
print(client.get_collections())
```
