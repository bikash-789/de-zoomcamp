import os
import gzip
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import requests

from dotenv import load_dotenv
from tqdm import tqdm
from google.cloud import storage


load_dotenv()


# -----------------------------
# Configuration
# -----------------------------

@dataclass(frozen=True)
class PipelineConfig:
    base_url: str = (
        "https://github.com/DataTalksClub/nyc-tlc-data/releases/download"
    )
    bucket_name: str = os.getenv(
        "GCP_GCS_BUCKET",
        "dtc-data-lake-bucketname"
    )
    chunk_size: int = 100_000


COLUMN_TYPES = {
    "VendorID": "Int64",
    "RatecodeID": "Int64",
    "PULocationID": "Int64",
    "DOLocationID": "Int64",
    "passenger_count": "Int64",
    "payment_type": "Int64",
    "trip_type": "Int64",
    "store_and_fwd_flag": "string",
    "trip_distance": "float64",
    "fare_amount": "float64",
    "extra": "float64",
    "mta_tax": "float64",
    "tip_amount": "float64",
    "tolls_amount": "float64",
    "ehailfee": "float64",
    "improvement_surcharge": "float64",
    "total_amount": "float64",
    "congestion_surcharge": "float64",
}


PICKUP_COLUMNS = {
    "yellow": [
        "tpep_pickup_datetime",
        "tpep_dropoff_datetime",
    ],
    "green": [
        "lpep_pickup_datetime",
        "lpep_dropoff_datetime",
    ],
}


# -----------------------------
# Download
# -----------------------------

def download_file(url: str, destination: Path):
    if destination.exists():
        print(f"Skipping download: {destination}")
        return

    with requests.get(url, stream=True) as response:
        response.raise_for_status()

        total = int(response.headers.get("content-length", 0))

        with (
            open(destination, "wb") as file,
            tqdm(
                total=total,
                desc=f"Downloading {destination.name}",
                unit="B",
                unit_scale=True,
            ) as progress,
        ):
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file.write(chunk)
                    progress.update(len(chunk))


# -----------------------------
# Transformation
# -----------------------------

def count_csv_rows(path: Path) -> int:
    with gzip.open(path, "rt") as file:
        return sum(1 for _ in file) - 1


def convert_csv_to_parquet(
    csv_file: Path,
    parquet_file: Path,
    service: str,
    chunk_size: int,
):
    if parquet_file.exists():
        print(f"Skipping conversion: {parquet_file}")
        return

    total_rows = count_csv_rows(csv_file)

    if total_rows <= 0:
        raise ValueError(f"Empty CSV: {csv_file}")

    reader = pd.read_csv(
        csv_file,
        dtype=COLUMN_TYPES,
        parse_dates=PICKUP_COLUMNS[service],
        compression="gzip",
        chunksize=chunk_size,
        low_memory=False,
    )

    writer = None

    with tqdm(
        total=total_rows,
        desc=f"Converting {csv_file.name}",
        unit="rows",
    ) as progress:

        for chunk in reader:
            table = pa.Table.from_pandas(chunk)

            if writer is None:
                writer = pq.ParquetWriter(
                    parquet_file,
                    table.schema,
                )

            writer.write_table(table)

            progress.update(len(chunk))

    if writer:
        writer.close()


# -----------------------------
# Upload
# -----------------------------

def upload_file(
    client: storage.Client,
    bucket_name: str,
    source: Path,
    destination: str,
) -> bool:

    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination)

    if blob.exists(client):
        print(f"Skipping upload: gs://{bucket_name}/{destination}")
        return False

    size = source.stat().st_size

    with open(source, "rb") as file:
        with tqdm.wrapattr(
            file,
            "read",
            total=size,
            desc=f"Uploading {source.name}",
            unit="B",
            unit_scale=True,
        ) as wrapped:

            blob.upload_from_file(
                wrapped,
                size=size,
            )

    print(
        f"Uploaded gs://{bucket_name}/{destination}"
    )
    return True


# -----------------------------
# Cleanup
# -----------------------------

def cleanup_local_files(*files: Path):
    """
    Remove local temporary files after successful processing.
    """
    for file in files:
        if file.exists():
            file.unlink()
            print(f"Deleted local file: {file}")


# -----------------------------
# Pipeline orchestration
# -----------------------------

def build_file_names(service, year, month):

    csv_name = (
        f"{service}_tripdata_{year}-{month}.csv.gz"
    )

    parquet_name = csv_name.replace(
        ".csv.gz",
        ".parquet",
    )

    return csv_name, parquet_name


def process_month(
    config: PipelineConfig,
    client: storage.Client,
    year: str,
    service: str,
    month: str,
):

    csv_name, parquet_name = build_file_names(
        service,
        year,
        month,
    )

    gcs_path = f"{service}/{parquet_name}"

    csv_path = Path(csv_name)
    parquet_path = Path(parquet_name)


    bucket = client.bucket(config.bucket_name)

    if bucket.blob(gcs_path).exists(client):
        print(
            f"Already uploaded: {gcs_path}"
        )
        return


    url = (
        f"{config.base_url}/"
        f"{service}/"
        f"{csv_name}"
    )

    download_file(url, csv_path)


    convert_csv_to_parquet(
        csv_path,
        parquet_path,
        service,
        config.chunk_size,
    )

    uploaded = upload_file(
        client,
        config.bucket_name,
        parquet_path,
        gcs_path,
    )

    if uploaded:
        cleanup_local_files(
            csv_path,
            parquet_path,
        )


def run_pipeline(
    year: str,
    service: str,
    config: PipelineConfig,
):

    client = storage.Client()

    for month in tqdm(
        range(1, 13),
        desc=f"{service} {year}",
    ):

        try:
            process_month(
                config,
                client,
                year,
                service,
                f"{month:02d}",
            )

        except requests.HTTPError:
            print(
                f"Missing file: {service} {year}-{month:02d}"
            )


# -----------------------------
# Entry point
# -----------------------------

if __name__ == "__main__":

    config = PipelineConfig()

    for year in ["2019", "2020", "2021"]:
        run_pipeline(
            year,
            "green",
            config,
        )

