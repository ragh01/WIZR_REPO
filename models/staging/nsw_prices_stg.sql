{{ config(
    materialized='view'
) }}

with source as (

    select *
    from {{ source('bronze', 'nsw_prices_raw') }}

),

renamed as (
    select
        trim(stationcode)                      as station_code,
        trim(fueltype)                         as fuel_type,
        price,
        try_to_timestamp(
            lastupdated,
            'DD/MM/YYYY HH24:MI:SS'
        )                                       as last_updated,
        loaded_at
    from source
)

select * from renamed