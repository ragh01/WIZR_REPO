{% snapshot snap_station %}

{{
    config(
        target_schema='silver',
        unique_key='station_code',
        strategy='check',
        check_cols=['station_name', 'brand', 'address', 'latitude', 'longitude']
    )
}}

select
    station_code,
    station_name,
    brand,
    address,
    latitude,
    longitude

from {{ ref('nsw_stations_stg') }}

{% endsnapshot %}