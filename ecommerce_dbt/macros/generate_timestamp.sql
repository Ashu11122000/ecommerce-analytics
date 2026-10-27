
{#
    Macro: generate_timestamp

    Purpose:
    - Return the current database timestamp.
    - Provide a reusable timestamp expression for dbt models.

    Important:
    - CURRENT_TIMESTAMP is evaluated by PostgreSQL when the SQL statement
      executes.
    - In a view, the value can change when the view is queried.
    - In a materialized table, the value is stored when the table is built
      or refreshed.
    - This macro does not independently record when a source row was
      originally ingested or updated.
#}

{% macro generate_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
