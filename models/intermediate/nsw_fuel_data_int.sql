{{ 
    config(
        materialized='table'
) }}

-- Daily grain: latest price observation per station, fuel type and day.

with prices as (
    select *,
    {{ cents_to_dollars('price') }} as price_per_litre_aud
    from {{ ref('nsw_prices_stg') }}
),

stations as (
    select *
    from {{ ref('nsw_stations_stg') }}
),

joined as (
    select
        s.station_code,
        p.fuel_type,
        p.price,
        p.price_per_litre_aud,
        p.last_updated,
        s.brand,
        s.station_name,
        s.address,
        s.latitude,
        s.longitude
    from prices p
    left join stations s
        on p.station_code = s.station_code
    where p.price > 0
      and p.last_updated is not null
),

daily as (
    select
        *,
        to_date(last_updated) as price_date
    from joined
    where station_code is not null
)

select *
from daily

-- Latest observation wins when multiple intraday prices exist.
qualify row_number() over (
    partition by station_code, fuel_type, price_date
    order by last_updated desc
) = 1