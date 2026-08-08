/*
  Fuel type dimension, sourced from the seed (governed code -> name mapping)
  rather than derived ad hoc from the fact — so the same code always resolves
  to the same name/category everywhere it's used.
*/
select
    {{ generate_surrogate_key(['fueltype_code']) }} as fueltype_key,
    fueltype_code,
    fueltype_name,
    product_category
from {{ ref('seed_fuel_type') }}
