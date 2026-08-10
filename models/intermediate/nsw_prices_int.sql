{{
    config(
        materialized='incremental',
        unique_key='price_observation_key',
        incremental_strategy='merge'
    )
}}

select

    {{ generate_surrogate_key([
        'station_code',
        'fuel_type'
    ]) }} as price_observation_key,

    station_code,
    fuel_type,
    price,
    last_updated,
    loaded_at

from {{ ref('nsw_prices_stg') }}

where station_code is not null
  and fuel_type is not null
  and price is not null
  and price >= 0
  and last_updated is not null

{% if is_incremental() %}
and loaded_at >= (select dateadd(hour, -24, max(loaded_at)) from {{ this }}
)
{% endif %}