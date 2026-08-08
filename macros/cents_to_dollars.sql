{# WA FuelWatch publishes prices in cents/litre. One place to convert -> $/litre. #}
{% macro cents_to_dollars(cents_col, precision=3) -%}
    round({{ cents_col }} / 100, {{ precision }})
{%- endmacro %}
