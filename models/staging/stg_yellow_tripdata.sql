SELECT
    -- identifiers
    cast(VendorID as int64) as vendor_id,
    cast(RatecodeID as int64) as rate_code_id,
    cast(PULocationID as int64) as pickup_location_id,
    cast(DOLocationID as int64) as dropoff_location_id,

    -- timestamps
    cast(tpep_pickup_datetime as timestamp) as pickup_datetime,
    cast(tpep_dropoff_datetime as timestamp) as dropoff_datetime,

    -- trip info
    store_and_fwd_flag,
    cast(passenger_count as int64) as passenger_count,
    cast(trip_distance as float64) as trip_distance,
    1 as trip_type,
    -- payment info
    cast(fare_amount as numeric) as fare_amount,
    cast(extra as numeric) as extra,
    cast(mta_tax as numeric) as mta_tax,
    cast(tip_amount as numeric) as tip_amount,
    cast(tolls_amount as numeric) as tolls_amount,
    cast(improvement_surcharge as numeric) as improvement_surcharge,
    cast(total_amount as numeric) as total_amount,
    0 as ehail_fee,
    cast(payment_type as int64) as payment_type,
    cast(congestion_surcharge as numeric) as congestion_surcharge

FROM {{ source('raw_data', 'yellow_tripdata_ext_partitoned') }}
WHERE vendorid is not null