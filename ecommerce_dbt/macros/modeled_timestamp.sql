
{#
    Macro: modeled_timestamp

    Purpose:
    - Provide a reusable timestamp expression for Gold-layer models.
    - Record the current PostgreSQL transaction timestamp.

    Important:
    - CURRENT_TIMESTAMP represents the start of the current transaction.
    - In a view, the expression is evaluated when the view is queried.
    - In a table, the evaluated value is stored when rows are built
      or refreshed.
    - In an incremental model, rows not updated during a run may retain
      their previously stored modeled_at value.
    - This macro does not independently record model execution history
      or the original source ingestion/update timestamp.
#}

{% macro modeled_timestamp() %}

    CURRENT_TIMESTAMP

{% endmacro %}
