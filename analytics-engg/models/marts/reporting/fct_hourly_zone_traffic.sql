/* 
    Aggregates trip data by 
        pickup zone, 
        service type, 
        and hour 
    to analyze hourly demand, revenue, and operational performance for fleet optimization and hotspot identification. 

    This model can answer several valuable business questions, including:
        1. Which pickup zones have the highest hourly demand?
        2. What are the peak demand hours across different zones?
        3. Which service type generates the most revenue by hour?
        4. Which pickup zones are the most profitable?
        6. What is the average trip distance and passenger count by hour?
        7. Where should drivers be positioned during peak hours?
        8. Which zones experience low demand and may require fewer drivers?
        9. How do tips and fares vary across locations and time periods?
        10. Which zones should be prioritized for fleet allocation and dispatch optimization?
*/

with hourly as (

select
    coalesce(pickup_zone, 'Unknown Zone') as pickup_zone,
    service_type,

    {% if target.type == 'bigquery' %}
        datetime_trunc(pickup_datetime, hour) as revenue_hour,
    {% elif target.type == 'duckdb' %}
        date_trunc('hour', pickup_datetime) as revenue_hour,
    {% endif %}

    count(trip_id) as total_hourly_trips,
    sum(total_amount) as total_hourly_revenue,
    sum(fare_amount) as total_hourly_fare,
    sum(tip_amount) as total_hourly_tips,
    avg(passenger_count) as avg_passenger_count,
    avg(trip_distance) as avg_trip_distance_miles,

    {% if target.type == 'bigquery' %}
        safe_divide(sum(total_amount), count(trip_id))
    {% else %}
        sum(total_amount) / nullif(count(trip_id),0)
    {% endif %} as avg_revenue_per_trip

from {{ ref('fact_trips') }}

group by
    pickup_zone,
    service_type,
    revenue_hour
)

select

{{ dbt_utils.generate_surrogate_key([
    "pickup_zone",
    "service_type",
    "cast(revenue_hour as string)"
]) }} as hourly_zone_pk,

*

from hourly
order by total_hourly_revenue desc