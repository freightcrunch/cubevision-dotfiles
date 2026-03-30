# SQLite — Lightweight Relational Database for Jetson

[SQLite](https://sqlite.org/) is a self-contained, serverless SQL database engine.
This directory contains configuration, helper scripts, and best practices for using SQLite on the Jetson Orin Nano.

## Quick Start

```bash
# Install SQLite + extensions and create default databases
bash setup-sqlite.sh

# Install only (no sample database)
bash setup-sqlite.sh --install

# Check version and status
bash setup-sqlite.sh --status
```

## Default Database Location

```
~/.local/share/sqlite/
├── databases/          # Your .db files live here
├── backups/            # Automated backup directory
└── sqlite.conf         # Runtime configuration (.sqliterc)
```

## Configuration

The included `.sqliterc` is symlinked to `~/.sqliterc` and configures:
- Column headers and box-mode output
- Foreign key enforcement
- WAL journal mode for concurrency
- Memory-mapped I/O (256 MB)

## Python Usage

```python
import sqlite3

conn = sqlite3.connect("~/.local/share/sqlite/databases/app.db")
conn.execute("PRAGMA journal_mode=WAL;")
conn.execute("PRAGMA foreign_keys=ON;")
```

## Backup

```bash
# Manual backup
bash setup-sqlite.sh --backup ~/.local/share/sqlite/databases/app.db

# Scheduled backups via cron (daily)
bash setup-sqlite.sh --cron
```
