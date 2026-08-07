# Honeynet Experimental Dataset — 2026-07-24

This directory contains the experimental evidence and processed datasets generated during the validation of the reproducible container-based honeynet platform developed in this repository.

The dataset accompanies the experimental evaluation of the platform and is provided to support transparency, independent inspection, and reproducibility of the reported results.

## Experimental Context

The data were generated during controlled experimental campaigns executed against the dual-environment honeynet architecture.

The platform maintains logically separated environments for benign and offensive activity while deploying functionally equivalent network services. This design enables the collection of service-specific telemetry under controlled experimental conditions.

The dataset published here covers the following services:

- FTP
- HTTP
- PostgreSQL
- REST API
- SMB
- SMTP
- SSH

The experimental evidence is provided at three different processing levels.

## Dataset Structure

```text
experiment-2026-07-24/
│
├── README.md
│
├── raw/
│   └── raw-service-logs.zip
│
├── events/
│   └── events.jsonl
│
└── processed/
    └── clean-service-datasets.zip
