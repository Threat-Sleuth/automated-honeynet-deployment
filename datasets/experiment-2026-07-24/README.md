# Honeynet Experimental Dataset — 2026-07-24

This directory contains the experimental evidence and processed datasets generated during the validation of the reproducible container-based honeynet platform developed in this repository.

The dataset accompanies the experimental evaluation of the platform and is provided to support transparency, independent inspection, and reproducibility of the reported results.

## Experimental Context

The data were generated during controlled experimental campaigns executed against the dual-environment honeynet architecture.

The platform maintains logically separated environments for benign and offensive activity while deploying functionally equivalent network services. This design enables the collection of service-specific telemetry under controlled experimental conditions.

The processed dataset published here covers the following services:

- FTP
- HTTP
- PostgreSQL
- REST API
- SMB
- SMTP
- SSH

The experimental material is provided at three complementary levels: raw service logs, campaign event records, and processed service-level datasets.

## Dataset Structure

```text
experiment-2026-07-24/
│
├── README.md
│
├── raw/
│   └── LOGS.240726.zip
│
├── events/
│   └── events.zip
│
└── processed/
    └── clean_datasets.zip
```

## 1. Raw Service Logs

`raw/LOGS.240726.zip`

This archive contains the raw service-level logs collected by the honeynet during the experimental campaigns.

The evidence is organized by service and experimental context, preserving the separation between benign activity and offensive/pentesting activity whenever applicable.

The archive contains raw telemetry associated with the evaluated network services:

- FTP
- HTTP
- PostgreSQL
- REST API
- SMB
- SMTP
- SSH

These files correspond to the original service-generated evidence before matching, correlation, labeling, or dataset construction. Consequently, their format and structure depend on the native logging mechanisms of each service.

The raw logs represent the lowest-level experimental evidence included in this release and provide the starting point for researchers interested in inspecting or reproducing the evidence-processing workflow.

## 2. Experimental Events

`events/events.zip`

This archive contains the structured event records generated during execution of the controlled experimental campaigns.

The archive contains the event data in JSON Lines (JSONL) format, where each line represents an individual experimental action or event.

Representative fields include:

| Field | Description |
|---|---|
| `campaign_id` | Identifier of the experimental campaign |
| `target_name` | Target instance used during the experiment |
| `host` | Target host |
| `port` | Target network port |
| `service` | Service associated with the event |
| `mode` | Experimental mode |
| `profile_name` | Campaign or execution profile |
| `attack_category_key` | Attack category identifier, when applicable |
| `capec_id` | CAPEC identifier, when applicable |
| `capec_category` | CAPEC category, when applicable |
| `label` | Experimental class label |
| `action` | Action executed during the experiment |
| `status` | Result or execution status |
| `latency_ms` | Observed action latency in milliseconds |
| `detail` | Additional execution information |
| `timestamp` | Event timestamp |
| `timestamp_epoch` | Event timestamp represented as Unix epoch time |

The event records provide the intermediate traceability layer between the controlled experimental campaigns and the telemetry subsequently collected from the honeynet services.

The event archive may contain records associated with additional platform components or services exercised during campaign execution that were not included in the final processed service-level datasets. The final processed dataset described below is restricted to the seven services selected for the infrastructure-level experimental evaluation.

## 3. Processed Service Datasets

`processed/clean_datasets.zip`

This archive contains the cleaned and structured service-level datasets produced after processing and correlating the experimental events with the telemetry collected by the honeynet.

The data are organized by service and operational class, preserving the distinction between benign and anomalous/offensive activity.

Seven services are represented:

- FTP
- HTTP
- PostgreSQL
- REST API
- SMB
- SMTP
- SSH

Representative fields include:

| Field | Description |
|---|---|
| `campaign_id` | Identifier of the source experimental campaign |
| `service` | Network service associated with the record |
| `mode` | Experimental operating mode |
| `label` | Benign/anomalous class information |
| `attack_category_key` | Attack category, when applicable |
| `capec_id` | CAPEC identifier, when applicable |
| `capec_category` | CAPEC classification, when applicable |
| `action` | Experimental action associated with the evidence |
| `status` | Execution status |
| `matched` | Indicates whether corresponding service evidence was identified |
| `matched_log_line` | Service log evidence correlated with the experimental event |

These datasets represent the final structured evidence included in this release.

No machine-learning transformation, feature selection, train/test splitting, or model-specific processing is included. Those operations belong to subsequent stages of the research workflow and are outside the scope of the infrastructure-level validation supported by this dataset.

## Processed Dataset Distribution

The processed service-level datasets contain **47,951 records** distributed across the seven evaluated services.

| Service | Benign | Anomaly | Total |
|---|---:|---:|---:|
| FTP | 818 | 1,807 | 2,625 |
| HTTP | 1,637 | 12,342 | 13,979 |
| PostgreSQL | 982 | 3,540 | 4,522 |
| REST API | 1,129 | 4,405 | 5,534 |
| SMB | 1,713 | 10,628 | 12,341 |
| SMTP | 2,544 | 4,180 | 6,724 |
| SSH | 828 | 1,398 | 2,226 |
| **Total** | **9,651** | **38,300** | **47,951** |

The class distribution reflects the experimental campaigns used to validate the platform and should not be interpreted as an attempt to reproduce the natural prevalence of benign and malicious activity in operational networks.

## Evidence Generation Workflow

The published artifacts represent complementary stages of the experimental evidence generation process:

```text
Controlled Experimental Campaigns
              |
              v
     Experimental Events
              |
              v
       Honeynet Services
              |
              v
       Raw Service Logs
              |
              v
 Service-Aware Processing
      and Correlation
              |
              v
  Clean Service Datasets
```

The three published artifacts therefore provide different views of the same experimental process:

1. **Experimental events** document the controlled actions executed during the campaigns.
2. **Raw service logs** preserve the original telemetry produced by the honeynet services.
3. **Processed service datasets** contain the structured evidence obtained after service-aware processing and correlation.

This organization allows researchers to inspect both the original experimental evidence and the resulting structured datasets instead of providing only the final derived data.

## Service Coverage

The raw event records may contain activity related to additional platform components or services used during campaign execution.

However, the processed dataset included in `clean_datasets.zip` is restricted to the seven services for which the final service-level evidence datasets were generated:

- FTP
- HTTP
- PostgreSQL
- REST API
- SMB
- SMTP
- SSH

This distinction reflects the experimental processing workflow rather than an inconsistency between the published artifacts.

## Scope of This Dataset Release

This dataset release is intended to document and support the experimental validation of the honeynet infrastructure and its service-aware evidence acquisition workflow.

The release therefore provides:

1. the original raw service logs;
2. the structured event records generated during the experimental campaigns;
3. the cleaned service-level datasets derived from the collected evidence.

Machine-learning training/test splits, trained models, classification reports, multiclass datasets, and other downstream analytical artifacts are intentionally excluded from this release because they are not required to reproduce the infrastructure-level validation addressed by the associated study.

The purpose of this release is therefore not to provide a preconfigured machine-learning benchmark, but to expose the experimental evidence generated by the platform at successive stages of the data-generation workflow.

## Reproducibility

The complete honeynet implementation is available in the root of this repository.

The repository includes the automated deployment scripts, Docker Compose definitions, service configurations, telemetry acquisition mechanisms, validation procedures, and supporting documentation required to recreate the experimental infrastructure.

Together, the platform implementation and the experimental data published in this directory support inspection of the workflow from controlled campaign execution to raw evidence acquisition and structured dataset generation.

Researchers may use the published raw logs and event records to inspect the original experimental evidence, while the processed datasets provide the structured output generated by the evidence-processing workflow.

## Citation

If you use this dataset or the associated honeynet platform in academic work, please cite the corresponding research article and this repository.

Full bibliographic information for the associated publication will be added after publication.

## License

The dataset is distributed under the terms specified in the repository license.

Users are responsible for ensuring that their use of the data complies with the applicable license terms and relevant legal and ethical requirements.
