
"""
Validate the generated SQL file before loading data into PostgreSQL.

Checks:
    1. The SQL file exists and is not empty.
    2. The SQL file contains INSERT statements for all expected RAW tables.
    3. The SQL file contains a TRUNCATE statement, if present, is clearly
       reported because it can replace existing data.
    4. No empty or obviously incomplete SQL statements are detected.
    5. A summary of INSERT statements by table is displayed.

Important:
    This is a static SQL-file validation script. It does not execute SQL,
    connect to PostgreSQL, or prove that every SQL statement is valid.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path


# ------------------------------------------------------------
# PROJECT CONFIGURATION
# ------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_SQL_FILE = PROJECT_ROOT / "sql" / "03_insert_raw_data.sql"

EXPECTED_RAW_TABLES = (
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
    "shipments",
    "returns",
)


# ------------------------------------------------------------
# SQL PATTERNS
# ------------------------------------------------------------

# Matches statements such as:
# INSERT INTO raw.customers (...)
# INSERT INTO "raw"."customers" (...)
# INSERT INTO customers (...)
INSERT_PATTERN = re.compile(
    r"""
    \bINSERT\s+INTO\s+
    (?:
        ["']?([A-Za-z_][A-Za-z0-9_]*)["']?
        \s*\.\s*
    )?
    ["']?([A-Za-z_][A-Za-z0-9_]*)["']?
    """,
    re.IGNORECASE | re.VERBOSE,
)

TRUNCATE_PATTERN = re.compile(
    r"\bTRUNCATE\s+(?:TABLE\s+)?",
    re.IGNORECASE,
)

# These patterns identify common signs of incomplete generated SQL.
INCOMPLETE_PATTERNS = {
    "unresolved template placeholder": re.compile(
        r"\{\{.*?\}\}|\$\{[^}]*\}"
    ),
    "Python None used as a SQL value": re.compile(
        r"\bVALUES\s*\([^;]*\bNone\b",
        re.IGNORECASE,
    ),
}


# ------------------------------------------------------------
# FILE HANDLING
# ------------------------------------------------------------

def read_sql_file(sql_file: Path) -> str | None:
    """Read the SQL file and return its contents."""
    if not sql_file.exists():
        print(f"ERROR: SQL file does not exist: {sql_file}")
        return None

    if not sql_file.is_file():
        print(f"ERROR: The specified path is not a file: {sql_file}")
        return None

    try:
        sql_text = sql_file.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        print(f"ERROR: Could not read SQL file: {exc}")
        return None

    if not sql_text.strip():
        print(f"ERROR: SQL file is empty: {sql_file}")
        return None

    return sql_text


# ------------------------------------------------------------
# VALIDATION HELPERS
# ------------------------------------------------------------

def remove_sql_comments(sql_text: str) -> str:
    """
    Remove ordinary SQL comments for static inspection.

    This supports:
        -- single-line comments
        /* block comments */

    This is not a complete PostgreSQL SQL parser. Comment-like text inside
    string literals can affect this simple preprocessing step, so database
    execution remains the final syntax check.
    """
    sql_text = re.sub(
        r"/\*.*?\*/",
        " ",
        sql_text,
        flags=re.DOTALL,
    )

    sql_text = re.sub(
        r"(?m)--.*$",
        " ",
        sql_text,
    )

    return sql_text


def find_insert_counts(sql_text: str) -> tuple[Counter, list[str]]:
    """
    Count INSERT statements by table.

    Returns:
        insert_counts: number of INSERT statements per table.
        non_raw_inserts: tables whose INSERT statements explicitly use
                         a schema other than raw.
    """
    insert_counts = Counter()
    non_raw_inserts = []

    for match in INSERT_PATTERN.finditer(sql_text):
        schema_name = match.group(1)
        table_name = match.group(2).lower()

        if schema_name and schema_name.lower() != "raw":
            non_raw_inserts.append(
                f"{schema_name}.{table_name}"
            )
            continue

        insert_counts[table_name] += 1

    return insert_counts, non_raw_inserts


def validate_sql(
    sql_text: str,
) -> tuple[list[str], list[str], Counter]:
    """
    Run static checks.

    Returns:
        errors: validation failures.
        warnings: items requiring review.
        insert_counts: INSERT statement counts by table.
    """
    errors: list[str] = []
    warnings: list[str] = []

    cleaned_sql = remove_sql_comments(sql_text)

    # --------------------------------------------------------
    # CHECK 1: INSERT STATEMENTS
    # --------------------------------------------------------

    insert_counts, non_raw_inserts = find_insert_counts(cleaned_sql)

    if not insert_counts:
        errors.append(
            "No usable INSERT INTO statements were found."
        )

    for table_name in EXPECTED_RAW_TABLES:
        if insert_counts[table_name] == 0:
            errors.append(
                f"Missing INSERT statements for raw.{table_name}."
            )

    if non_raw_inserts:
        warnings.append(
            "INSERT statements explicitly target schemas other than raw: "
            + ", ".join(sorted(set(non_raw_inserts)))
        )

    # --------------------------------------------------------
    # CHECK 2: TRUNCATE STATEMENTS
    # --------------------------------------------------------

    if TRUNCATE_PATTERN.search(cleaned_sql):
        warnings.append(
            "TRUNCATE statement detected. Loading this SQL may delete "
            "existing table rows before inserting new data."
        )
    else:
        warnings.append(
            "No TRUNCATE statement detected. Confirm whether this matches "
            "the intended data-generation and loading strategy."
        )

    # --------------------------------------------------------
    # CHECK 3: OBVIOUSLY INCOMPLETE SQL
    # --------------------------------------------------------

    for description, pattern in INCOMPLETE_PATTERNS.items():
        if pattern.search(cleaned_sql):
            errors.append(
                f"Potential {description} detected."
            )

    # --------------------------------------------------------
    # CHECK 4: BASIC STATEMENT TERMINATION
    # --------------------------------------------------------

    stripped_sql = cleaned_sql.rstrip()

    if stripped_sql and not stripped_sql.endswith(";"):
        warnings.append(
            "The file does not end with a semicolon. "
            "Review the final SQL statement."
        )

    # --------------------------------------------------------
    # CHECK 5: EXPECTED TABLE COVERAGE
    # --------------------------------------------------------

    detected_tables = set(insert_counts.keys())
    unexpected_tables = detected_tables - set(EXPECTED_RAW_TABLES)

    if unexpected_tables:
        warnings.append(
            "Additional INSERT target tables were found: "
            + ", ".join(sorted(unexpected_tables))
        )

    return errors, warnings, insert_counts


# ------------------------------------------------------------
# REPORTING
# ------------------------------------------------------------

def print_report(
    sql_file: Path,
    sql_text: str,
    errors: list[str],
    warnings: list[str],
    insert_counts: Counter,
) -> None:
    """Print a readable validation report."""
    print("\n" + "=" * 65)
    print("RAW DATA SQL VALIDATION REPORT")
    print("=" * 65)

    print(f"Project root : {PROJECT_ROOT}")
    print(f"SQL file     : {sql_file}")
    print(f"File size    : {len(sql_text.encode('utf-8')):,} bytes")

    print("\nINSERT statement counts")
    print("-" * 65)

    for table_name in EXPECTED_RAW_TABLES:
        count = insert_counts[table_name]
        status = "OK" if count > 0 else "MISSING"

        print(
            f"raw.{table_name:<15} "
            f"{count:>6} statement(s)  [{status}]"
        )

    print(
        f"\nTotal INSERT statements: {sum(insert_counts.values())}"
    )

    print("\nWarnings")
    print("-" * 65)

    if warnings:
        for warning in warnings:
            print(f"WARNING: {warning}")
    else:
        print("No warnings.")

    print("\nErrors")
    print("-" * 65)

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
    else:
        print("No static validation errors.")

    print("\nFinal result")
    print("-" * 65)

    if errors:
        print("FAILED: Fix the errors before loading the SQL file.")
    else:
        print(
            "PASSED: Static checks passed. Review warnings and "
            "continue with database validation."
        )

    print("=" * 65)


# ------------------------------------------------------------
# COMMAND-LINE ARGUMENTS
# ------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    """Read command-line options."""
    parser = argparse.ArgumentParser(
        description=(
            "Validate the generated e-commerce RAW SQL file "
            "before loading it into PostgreSQL."
        )
    )

    parser.add_argument(
        "--sql-file",
        type=Path,
        default=DEFAULT_SQL_FILE,
        help=(
            "Path to the SQL file. Defaults to "
            "sql/03_insert_raw_data.sql in the project root."
        ),
    )

    return parser.parse_args()


# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

def main() -> int:
    """Run validation and return an appropriate process exit code."""
    args = parse_args()

    sql_file = args.sql_file

    if not sql_file.is_absolute():
        sql_file = PROJECT_ROOT / sql_file

    print("Starting RAW SQL validation...")

    sql_text = read_sql_file(sql_file)

    if sql_text is None:
        return 1

    errors, warnings, insert_counts = validate_sql(sql_text)

    print_report(
        sql_file=sql_file,
        sql_text=sql_text,
        errors=errors,
        warnings=warnings,
        insert_counts=insert_counts,
    )

    # Return nonzero if any validation errors were found.
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
