
{#
    Macro: safe_divide

    Purpose:
    - Safely divide a numerator by a denominator.
    - Prevent division-by-zero errors.
    - Return NULL when the denominator is zero or NULL.

    Parameters:
    - numerator: SQL expression for the numerator.
    - denominator: SQL expression for the denominator.

    Behavior:
    - Denominator is zero: return NULL.
    - Denominator is NULL: return NULL.
    - Numerator is NULL: return NULL.
    - Otherwise: return numerator divided by denominator.

    Important:
    - The caller is responsible for choosing appropriate data types
      and precision for financial calculations.
#}

{% macro safe_divide(numerator, denominator) %}

    CASE
        WHEN ({{ denominator }}) IS NULL
          OR ({{ denominator }}) = 0
            THEN NULL
        WHEN ({{ numerator }}) IS NULL
            THEN NULL
        ELSE
            ({{ numerator }})::NUMERIC
            / NULLIF(({{ denominator }})::NUMERIC, 0)
    END

{% endmacro %}
