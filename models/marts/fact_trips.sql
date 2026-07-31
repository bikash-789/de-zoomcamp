/*
    To Do:
        - One row per trip (doesn't matter if yellow or green).
        - Add a primary key (trip_id). It has to be unique
        - Find all the duplicates, understand why they happen, and fix them.
        - Find a way to enrich the column payment type. 
*/

{{ config(materialized="table") }}

with trips as (

    select *
    from {{ ref("int_trips_unioned") }}

),

deduplicated as (
    select
        *,
        row_number() over (
            partition by
                vendor_id,
                pickup_datetime,
                dropoff_datetime,
                pickup_location_id,
                dropoff_location_id,
                fare_amount
            order by vendor_id
        ) as rn

    from trips
),

cleaned as (
    select *
    from deduplicated
    where rn = 1
),

final as (
    select
        -- primary key
        to_hex(
            md5(
                concat(
                    cast(vendor_id as string),
                    cast(pickup_datetime as string),
                    cast(dropoff_datetime as string),
                    cast(pickup_location_id as string),
                    cast(dropoff_location_id as string),
                    cast(fare_amount as string),
                    cast(trip_distance as string)
                )
            )
        ) as trip_id,
        vendor_id,
        rate_code_id,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        store_and_fwd_flag,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        total_amount,
        congestion_surcharge,
        payment_type,
        {{ get_payment_type_name('payment_type') }} as payment_type_description

    from cleaned
)

select *
from final