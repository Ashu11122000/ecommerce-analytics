
{#
    Macro: calculate_date_key

    Purpose:
    - Convert a date or timestamp expression into an integer date key.
    - Keep fact-table date keys consistent with dim_date.date_key.

    Parameter:
    - date_column: SQL expression containing a date or timestamp.

    Output:
    - Integer in YYYYMMDD format.
    - NULL when the input expression is NULL.

    Example:
    - 2026-10-27 becomes 20261027.

    Important:
    - Pass a SQL expression or column reference, not a quoted date value.
    - The date key must correspond to a date present in dim_date.
#}

{% macro calculate_date_key(date_column) %}

    CASE
        WHEN {{ date_column }} IS NOT NULL
            THEN TO_CHAR(
                {{ date_column }}::DATE,
                'YYYYMMDD'
            )::INTEGER
        ELSE NULL
    END

{% endmacro %}
