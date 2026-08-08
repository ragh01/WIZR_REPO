{#
  Use the schema name exactly as configured (SILVER / GOLD / BRONZE),
  instead of dbt's default "<target>_<schema>" prefixing.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
