{{
    config(
        materialized='incremental',
        unique_key='station_code',
        incremental_strategy='merge'
    )
}}

select
    station_id,
    station_code,
    brand,
    brand_id,
    station_name,
    address,
    latitude,
    longitude,
    loaded_at
from {{ ref('nsw_stations_stg') }}

where station_code is not null

{% if is_incremental() %}
    and loaded_at >= (select dateadd(hour, -24, max(loaded_at)) from {{ this }}
    )

{% endif %}