{{
    config(
        materialized='table'
    )
}}

with prices as (
    select
        price_observation_key,
        station_code,
        fuel_type,
        price,
        last_updated,
        loaded_at,
        {{ cents_to_dollars('price') }} as price_per_litre_aud
    from {{ ref('nsw_prices_int') }}
),

stations as (
    select
        station_code,
        brand,
        station_name,
        address,
        latitude,
        longitude
    from {{ ref('nsw_stations_int') }}
),

final as (
    select
        p.price_observation_key,
        p.station_code,
        p.fuel_type,
        p.price,
        p.price_per_litre_aud,
        p.last_updated,
        to_date(p.last_updated) as price_date,
        s.brand,
        s.station_name,
        s.address,
        s.latitude,
        s.longitude,
        p.loaded_at
    from prices p
    left join stations s
        on p.station_code = s.station_code
)

select * from final