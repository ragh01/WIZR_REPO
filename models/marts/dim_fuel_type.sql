{{ 
    config(
        materialized='table'
) }}

-- Governed fuel type mapping from seed reference data.

select
    {{ generate_surrogate_key(['fueltype_code']) }} as fueltype_key,
    fueltype_code,
    fueltype_name,
    product_category
from {{ ref('seed_fuel_type') }}
