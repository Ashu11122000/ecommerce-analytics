
{#
    Macro: modeled_timestamp

    Purpose:
    - Provide a reusable timestamp expression for Gold-layer models.
    - Record the timestamp associated with executing the model SQL.

    Important:
    - CURRENT_TIMESTAMP returns the current transaction timestamp in PostgreSQL.
    - For a materialized table, the value is stored when the table is built
      or refreshed.
    - For a view, the value may change when the view is queried.
#}

{% macro modeled_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
