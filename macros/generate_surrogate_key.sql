{#
  Self-contained replacement for dbt_utils.generate_surrogate_key.
  No package dependency — avoids failures when dbt_utils isn't installed
  (e.g. `dbt deps` didn't run, or a network-restricted environment).

  Same behaviour as the dbt_utils macro: casts each column to string,
  treats null/empty as a distinct placeholder (so NULL and '' don't
  collide with a real value), joins with '-', then MD5-hashes the result.

  Usage: {{ generate_surrogate_key(['station_code']) }}
         {{ generate_surrogate_key(['trading_name', 'address', 'postcode']) }}
#}
{% macro generate_surrogate_key(column_list) -%}
    md5(
        concat_ws('-',
            {%- for col in column_list %}
            coalesce(nullif(cast({{ col }} as varchar), ''), '_dbt_surrogate_key_null_')
            {%- if not loop.last %},{% endif %}
            {%- endfor %}
        )
    )
{%- endmacro %}