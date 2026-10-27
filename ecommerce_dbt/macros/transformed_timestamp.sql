
{#
    Macro: transformed_timestamp

    Purpose:
    - Provide a reusable timestamp expression for Silver-layer models.
    - Record the timestamp associated with executing the transformation SQL.

    Important:
    - CURRENT_TIMESTAMP returns PostgreSQL's current transaction timestamp.
    - For a view, the timestamp may change whenever the view is queried.
    - For a materialized table, the value is stored when the table is built
      or refreshed.
    - This timestamp does not represent the original source update time.
#}

{% macro transformed_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
