/*
  SILVER staging: the only place messy work happens.
    - cast + standardise types
    - reject invalid rows (bad dates / non-positive prices)
    - enforce the grain via dedup: one price per station-product-day (WA 24h rule)
  Downstream Gold can therefore trust every row.
*/
with source as (
    select * from {{ source('bronze', 'raw_wa_fuel_prices') }}
),

cleaned as (
    select
        try_to_date(publish_date, 'DD/MM/YYYY')      as price_date,
        trim(trading_name)                           as trading_name,
        initcap(trim(brand_description))             as brand,
        upper(trim(product_description))             as product,
        try_to_number(product_price, 10, 2)          as price_cents,
        trim(address)                                as address,
        initcap(trim(location))                      as suburb,
        trim(postcode)                               as postcode,
        initcap(trim(area_description))              as area,
        initcap(trim(region_description))            as region,
        loaded_at
    from source
    where try_to_date(publish_date, 'DD/MM/YYYY') is not null   -- drop unparseable dates
      and try_to_number(product_price, 10, 2) > 0               -- drop invalid / zero prices
)

select
    price_date,
    trading_name,
    brand,
    product,
    price_cents,
    {{ cents_to_dollars('price_cents') }}            as price_per_litre_aud,
    address,
    suburb,
    postcode,
    area,
    region
from cleaned
-- Grain enforcement + idempotent dedup: keep the most-recently-loaded row
-- for each station x product x day. Re-running a load is therefore harmless.
qualify row_number() over (
    partition by trading_name, address, postcode, product, price_date
    order by loaded_at desc
) = 1
