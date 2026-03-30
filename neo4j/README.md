# Neo4j — Graph Database for Jetson

[Neo4j](https://neo4j.com/) is a native graph database with Cypher query language.
This directory contains configuration and setup scripts for running Neo4j on the Jetson Orin Nano.

## Quick Start

```bash
# Install Neo4j Community Edition
bash setup-neo4j.sh

# Run via Docker instead
bash setup-neo4j.sh --docker

# Check status
bash setup-neo4j.sh --status
```

## Endpoints

| Service         | URL                              |
|-----------------|----------------------------------|
| Browser UI      | `http://127.0.0.1:7474`         |
| Bolt protocol   | `bolt://127.0.0.1:7687`         |

Default credentials: `neo4j` / `neo4j` (you'll be prompted to change on first login).

## Storage

```
~/.local/share/neo4j/
├── data/           # Database files
├── logs/           # Server logs
├── import/         # CSV import directory
├── plugins/        # Extensions (APOC, GDS, etc.)
└── conf/           # Runtime configuration
```

## Configuration

Edit `neo4j.conf` to tune:
- **Memory**: heap size, page cache (tuned for 8 GB Jetson)
- **Network**: listen addresses, bolt connector
- **Security**: authentication, default database

## Python Client

```bash
pip install neo4j
```

```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver("bolt://127.0.0.1:7687", auth=("neo4j", "password"))
with driver.session() as session:
    result = session.run("RETURN 'Hello from Neo4j' AS message")
    print(result.single()["message"])
driver.close()
```

## Cypher Shell

```bash
cypher-shell -u neo4j -p password
```
