{% macro generate_surrogate_key(column_list) -%}
    
    md5(
        concat_ws(
            '-',
            {% for col in column_list %}
            coalesce(
                nullif(cast({{ col }} as varchar), ''),
                '*dbt_surrogate_key_null*'
            )
            {% if not loop.last %},{% endif %}
            {% endfor %}
        )
    )
    
{%- endmacro %}