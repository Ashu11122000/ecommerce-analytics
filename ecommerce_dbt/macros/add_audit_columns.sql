{% macro add_audit_columns(
    include_loaded_at=false,
    include_transformed_at=false,
    include_modeled_at=false
) %}

    {% set columns = [] %}

    {% if include_loaded_at %}
        {% do columns.append("CURRENT_TIMESTAMP AS loaded_at") %}
    {% endif %}

    {% if include_transformed_at %}
        {% do columns.append("CURRENT_TIMESTAMP AS transformed_at") %}
    {% endif %}

    {% if include_modeled_at %}
        {% do columns.append("CURRENT_TIMESTAMP AS modeled_at") %}
    {% endif %}

    {{ columns | join(",\n    ") }}

{% endmacro %}