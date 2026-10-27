
{#
    Macro: add_audit_columns

    Purpose:
    - Generate SQL expressions for optional audit timestamp columns.
    - Allow models to include only the audit columns they need.

    Parameters:
    - include_loaded_at:
        Adds loaded_at, representing Bronze-layer processing time.
    - include_transformed_at:
        Adds transformed_at, representing Silver-layer processing time.
    - include_modeled_at:
        Adds modeled_at, representing Gold-layer processing time.

    Important:
    - CURRENT_TIMESTAMP represents the start time of the current
      PostgreSQL transaction.
    - In a view, these expressions are evaluated when the view
      is queried, so they do not persist the original build time.
    - In a table, the values are stored when the table is built
      or when the relevant rows are inserted or updated.
    - This macro generates SQL expressions; it does not itself
      configure model materialization or incremental behavior.
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

    {% if columns | length == 0 %}
        {{ exceptions.raise_compiler_error(
            "add_audit_columns: Enable at least one audit column."
        ) }}
    {% endif %}

    {{ columns | join(",\n    ") }}

{% endmacro %}
