{{ config(
    materialized='view'
) }}

with source as (
    select *
    from {{ source('bronze', 'nsw_stations_raw') }}
),

renamed as (
    select
        trim(stationid)                         as station_id,
        trim(code)                              as station_code,
        trim(brand)                             as brand,
        trim(brandid)                           as brand_id,
        trim(name)                              as station_name,
        trim(address)                           as address,
        try_to_decimal(latitude, 10, 6)         as latitude,
        try_to_decimal(longitude, 10, 6)        as longitude,
        loaded_at
    from source
)

select * from renamed