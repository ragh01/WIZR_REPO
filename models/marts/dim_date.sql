with dates as (
    select distinct price_date from {{ ref('nsw_fuel_data_int') }}
)
select
    to_number(to_char(price_date, 'YYYYMMDD'))  as date_key,   -- smart surrogate key
    price_date,
    year(price_date)                            as year,
    month(price_date)                           as month,
    monthname(price_date)                       as month_name,
    to_char(price_date, 'YYYY-MM')              as year_month,
    day(price_date)                             as day_of_month,
    dayname(price_date)                         as day_name,
    (dayofweekiso(price_date) in (6, 7))        as is_weekend
from dates
