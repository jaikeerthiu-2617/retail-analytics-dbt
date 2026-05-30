{% macro generate_surrogate_key(fields) %}
    md5(
        concat(
            {%- for field in fields -%}
                coalesce(cast({{ field }} as varchar), '')
                {%- if not loop.last -%}, '||', {%- endif -%}
            {%- endfor -%}
        )
    )
{% endmacro %}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
