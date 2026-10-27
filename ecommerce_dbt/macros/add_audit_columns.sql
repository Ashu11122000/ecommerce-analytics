
{#
    Macro: add_audit_columns

    Purpose:
    - Dynamically generate SQL expressions for audit columns.
    - Allow models to include only the timestamps they require.

    Parameters:
    - include_loaded_at:
        Adds loaded_at, representing Bronze-layer processing time.
    - include_transformed_at:
        Adds transformed_at, representing Silver-layer processing time.
    - include_modeled_at:
        Adds modeled_at, representing Gold-layer modeling time.

    Important:
    - CURRENT_TIMESTAMP represents the time the SQL statement executes.
    - In a view, these values may change whenever the view is queried.
    - For persisted build timestamps, use a table or another mechanism
      that records the actual processing timestamp.
#}

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

    {% if columns | length > 0 %}
        {{ columns | join(",\n    ") }}
    {% else %}
        {{ exceptions.raise_compiler_error(
            "add_audit_columns: Enable at least one audit column."
        ) }}
    {% endif %}

{% endmacro %}
