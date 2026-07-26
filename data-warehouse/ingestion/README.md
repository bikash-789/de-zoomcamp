# NYC TLC Data Ingestion Pipeline

## Overview

This part of project implements a data ingestion pipeline that:

1. Downloads NYC TLC trip data from GitHub.
2. Converts compressed CSV files (`.csv.gz`) into optimized Parquet files.
3. Uploads Parquet files to Google Cloud Storage (GCS).
4. Removes temporary local files after successful processing.

## Pipeline Flow

```text
GitHub TLC Dataset
        |
        v
Download CSV.GZ
        |
        v
Convert CSV.GZ → Parquet
        |
        v
Upload Parquet → Google Cloud Storage
        |
        v
Cleanup Local Files
```

---

# Prerequisites

## Install Dependencies

Run:

```bash
uv sync
```

This creates the virtual environment and installs dependencies from `pyproject.toml`.

---

## Environment Configuration

Create a `.env` file:

```bash
cp .env-example .env
```

Configure:

```env
GCP_GCS_BUCKET=<your-gcs-bucket-name>

GOOGLE_APPLICATION_CREDENTIALS=<path-to-service-account-json>
```

You can also use Google Application Default Credentials (ADC).

---

# Pipeline Architecture

The pipeline is divided into independent components:

| Component | Responsibility |
|---|---|
| `download_file()` | Downloads raw TLC data |
| `convert_csv_to_parquet()` | Converts CSV.GZ into Parquet |
| `upload_file()` | Uploads Parquet files to GCS |
| `cleanup_local_files()` | Removes temporary files |
| `process_month()` | Coordinates monthly processing |
| `run_pipeline()` | Executes the pipeline |

---

# Processing Flow

## 1. Generate File Names

For every service, year, and month:

Example:

```
service = yellow
year = 2019
month = 01
```

Generated files:

```
yellow_tripdata_2019-01.csv.gz

yellow_tripdata_2019-01.parquet
```

GCS destination:

```
gs://<bucket>/yellow/yellow_tripdata_2019-01.parquet
```

---

# 2. Check Existing Files

Before processing, the pipeline checks whether the Parquet file already exists in GCS.

Example:

```
gs://<bucket>/yellow/yellow_tripdata_2019-01.parquet
```

If the file exists:

```
Already uploaded. Skipping.
```

This prevents unnecessary downloads and processing.

---

# 3. Download CSV Data

Raw TLC data is downloaded from:

```
https://github.com/DataTalksClub/nyc-tlc-data/releases
```

Example:

```
yellow_tripdata_2019-01.csv.gz
```

Features:

- Streaming download
- Progress tracking
- Skip existing files

---

# 4. Convert CSV.GZ to Parquet

Large CSV files are processed in chunks.

Example configuration:

```python
chunk_size = 100000
```

Processing:

```
CSV.GZ
 |
 |-- Read chunk
 |
 |-- Convert to Pandas DataFrame
 |
 |-- Convert to PyArrow Table
 |
 |-- Write Parquet
 |
Repeat
```

Benefits:

- Reduced memory usage
- Faster processing
- Better analytical performance
- Consistent schema

---

# 5. Data Type Management

The pipeline enforces column types:

Example:

| Column | Type |
|---|---|
| VendorID | Int64 |
| passenger_count | Int64 |
| trip_distance | float64 |
| fare_amount | float64 |
| store_and_fwd_flag | string |

This prevents schema inconsistencies during ingestion.

---

# 6. Upload to Google Cloud Storage

After conversion:

Local file:

```
yellow_tripdata_2019-01.parquet
```

Uploaded location:

```
gs://<bucket>/yellow/yellow_tripdata_2019-01.parquet
```

Features:

- Upload progress bar
- Existing file detection
- Streaming upload

---

# 7. Cleanup Local Storage

After successful upload:

Deleted:

```
yellow_tripdata_2019-01.csv.gz

yellow_tripdata_2019-01.parquet
```

Purpose:

- Prevent disk space issues
- Keep local environment clean
- Treat GCS as the source of truth

---

# Final Architecture

```text
                    +----------------+
                    | GitHub TLC     |
                    | Dataset        |
                    +-------+--------+
                            |
                            |
                     download_file()
                            |
                            v
                    +---------------+
                    | CSV.GZ File   |
                    +---------------+
                            |
                            |
              convert_csv_to_parquet()
                            |
                            v
                    +---------------+
                    | Parquet File  |
                    +---------------+
                            |
                            |
                      upload_file()
                            |
                            v
                    +---------------+
                    | Google Cloud  |
                    | Storage       |
                    +---------------+
                            |
                            |
                 cleanup_local_files()
                            |
                            v
                    Local cleanup
```

---
