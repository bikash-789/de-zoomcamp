-- Creating tables from GCS bucket
CREATE OR REPLACE EXTERNAL TABLE `project-ce53f020-7477-40f6-a2c.de_zoomcamp_ds.yellow_tripdata_ext`
  OPTIONS (
    format = 'PARQUET',
    uris =
      [
        'gs://de-zoomcamp-bckt/yellow/yellow_tripdata_2019-*.parquet',
        'gs://de-zoomcamp-bckt/yellow/yellow_tripdata_2020-*.parquet',
        'gs://de-zoomcamp-bckt/yellow/yellow_tripdata_2021-*.parquet']);

-- Create non-partitoned table from external table
CREATE OR REPLACE TABLE `de_zoomcamp_ds.yellow_tripdata_ext_non_partitoned`
AS
SELECT * FROM `de_zoomcamp_ds.yellow_tripdata_ext`;

-- Create partitoned table from external table
CREATE OR REPLACE TABLE `de_zoomcamp_ds.yellow_tripdata_ext_partitoned`
  PARTITION BY
    DATE(tpep_pickup_datetime)
AS
SELECT * FROM `de_zoomcamp_ds.yellow_tripdata_ext`;

-- Impact of Partition
-- ___________________________________
-- 277 ms -> Bytes processed - 1.83 GB
SELECT DISTINCT (VendorID)
FROM `de_zoomcamp_ds.yellow_tripdata_ext_non_partitoned`
WHERE DATE(tpep_pickup_datetime) BETWEEN '2019-06-01' AND '2019-06-30';

-- 244 ms -> Bytes processed - 105.91 MB
SELECT DISTINCT (VendorID)
FROM `de_zoomcamp_ds.yellow_tripdata_ext_partitoned`
WHERE DATE(tpep_pickup_datetime) BETWEEN '2019-06-01' AND '2019-06-30';

-- ________________________________________________
-- Let's look into each partitioned distribution
SELECT table_name, partition_id, total_rows
FROM `de_zoomcamp_ds.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'yellow_tripdata_ext_partitoned'
ORDER BY total_rows DESC;

-- Creating a parition and cluster table
CREATE OR REPLACE TABLE `de_zoomcamp_ds.yellow_tripdata_ext_partioned_cluster`
  PARTITION BY DATE(tpep_pickup_datetime)
  CLUSTER BY VendorID
AS
SELECT * FROM `de_zoomcamp_ds.yellow_tripdata_ext`;

-- _______________________________________________________________
-- Query
-- 225 ms -> Bytes processed - 1.06 GB
SELECT COUNT(*) AS trips
FROM `de_zoomcamp_ds.yellow_tripdata_ext_partitoned`
WHERE
  DATE(tpep_pickup_datetime) BETWEEN '2019-06-01' AND '2020-12-31'
  AND VendorID = 1;

-- 231 ms -> Bytes processed - 852.66 MB
SELECT COUNT(*) AS trips
FROM `de_zoomcamp_ds.yellow_tripdata_ext_partioned_cluster`
WHERE
  DATE(tpep_pickup_datetime) BETWEEN '2019-06-01' AND '2020-12-31'
  AND VendorID = 1;
