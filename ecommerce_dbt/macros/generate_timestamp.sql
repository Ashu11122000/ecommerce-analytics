
{#
    Macro: generate_timestamp

    Purpose:
    - Return PostgreSQL's current transaction timestamp.
    - Provide a reusable timestamp expression for dbt models.

    Important:
    - CURRENT_TIMESTAMP represents the start of the current transaction.
    - In a view, the expression is evaluated when the view is queried.
    - In a table, the evaluated value is stored when rows are built
      or refreshed.
    - This macro does not record source ingestion or source update time.
    - This macro does not independently record model execution history.
#}

{% macro generate_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
