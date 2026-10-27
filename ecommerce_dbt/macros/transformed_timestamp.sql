
{#
    Macro: transformed_timestamp

    Purpose:
    - Provide a reusable timestamp expression for Silver-layer models.
    - Record the current PostgreSQL transaction timestamp.

    Important:
    - CURRENT_TIMESTAMP returns the start time of the current
      database transaction.
    - In a view, the expression is evaluated when the view is queried.
    - In a table, the evaluated value is stored when rows are built
      or refreshed.
    - This timestamp is not the source record's update timestamp.
    - This macro generates an expression only; it does not configure
      model materialization or control when a model is refreshed.
#}

{% macro transformed_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
