"""
Check connectivity to the project's PostgreSQL database.

Purpose
-------
- Load DATABASE_URL from the environment or a root-level .env file.
- Connect to PostgreSQL without printing credentials.
- Report server, database, user, and PostgreSQL version.
- Check whether the expected raw schema and tables exist.
- Return a non-zero exit code when the connection fails.

Expected environment variable
-----------------------------
DATABASE_URL=postgresql://username:password@localhost:5432/database_name

The script does not create a database, create tables, or modify data.
Run it from any working directory; paths are resolved relative to this file.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

try:
    import psycopg
except ImportError:
    psycopg = None


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"

EXPECTED_RAW_TABLES = (
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
    "shipments",
    "returns",
)


def load_env_file(env_path: Path) -> None:
    """
    Load simple KEY=VALUE entries from a .env file without overriding
    environment variables that are already set.

    This intentionally supports common .env syntax without requiring
    python-dotenv. For complex values or shell-specific expansions,
    set DATABASE_URL in the terminal or install/use python-dotenv.
    """
    if not env_path.is_file():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        # Ignore blank lines and comments.
        if not line or line.startswith("#"):
            continue

        # Accept an optional "export " prefix.
        if line.startswith("export "):
            line = line[len("export ") :].strip()

        if "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if not key:
            continue

        # Remove matching surrounding quotes only.
        if (
            len(value) >= 2
            and value[0] == value[-1]
            and value[0] in ("'", '"')
        ):
            value = value[1:-1]

        # Do not overwrite variables supplied by the current environment.
        os.environ.setdefault(key, value)


def get_database_url() -> Optional[str]:
    """Return DATABASE_URL after loading the project's .env file."""
    load_env_file(ENV_FILE)
    database_url = os.getenv("DATABASE_URL", "").strip()
    return database_url or None


def describe_database_url(database_url: str) -> tuple[str, str]:
    """
    Return a safe host/database summary for error messages.
    Never return or print the URL itself because it may contain a password.
    """
    parsed = urlparse(database_url)
    host = parsed.hostname or "(host not specified)"
    database = parsed.path.lstrip("/") or "(database not specified)"
    return host, database


def check_connection(database_url: str) -> bool:
    """Connect to PostgreSQL and check the expected raw tables."""
    if psycopg is None:
        print("ERROR: The 'psycopg' package is not installed.")
        print("Install it in the active virtual environment with:")
        print("  python -m pip install 'psycopg[binary]'")
        return False

    host, database = describe_database_url(database_url)

    print("PostgreSQL connection check")
    print("=" * 32)
    print(f"Project root : {PROJECT_ROOT}")
    print(f".env file    : {'found' if ENV_FILE.is_file() else 'not found'}")
    print(f"Host         : {host}")
    print(f"Database     : {database}")
    print()

    try:
        # A context-managed connection is closed automatically.
        # A short timeout prevents the script from hanging indefinitely.
        with psycopg.connect(
            database_url,
            connect_timeout=8,
            application_name="ecommerce_analytics_connection_check",
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        current_database(),
                        current_user,
                        inet_server_addr()::text,
                        inet_server_port(),
                        version()
                    """
                )
                database_name, database_user, server_address, server_port, version = (
                    cursor.fetchone()
                )

                print("CONNECTION SUCCESSFUL")
                print(f"Connected database : {database_name}")
                print(f"Connected user     : {database_user}")
                print(f"Server address     : {server_address or 'local/socket connection'}")
                print(f"Server port        : {server_port or 'not reported'}")
                print(f"Server version     : {version.split(',')[0]}")
                print()

                cursor.execute(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM information_schema.schemata
                        WHERE schema_name = 'raw'
                    )
                    """
                )
                raw_schema_exists = cursor.fetchone()[0]

                if not raw_schema_exists:
                    print("RAW schema check   : NOT FOUND")
                    print(
                        "The connection works, but schema 'raw' does not exist yet."
                    )
                    print(
                        "Create/load the raw schema using your project's SQL scripts."
                    )
                    return True

                print("RAW schema check   : FOUND")

                cursor.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'raw'
                      AND table_type = 'BASE TABLE'
                    """
                )
                existing_tables = {row[0] for row in cursor.fetchall()}

                print("\nExpected raw table checks:")
                missing_tables = []

                for table_name in EXPECTED_RAW_TABLES:
                    if table_name in existing_tables:
                        print(f"  [OK]      raw.{table_name}")
                    else:
                        print(f"  [MISSING] raw.{table_name}")
                        missing_tables.append(table_name)

                if missing_tables:
                    print(
                        "\nThe database connection is healthy, but some expected "
                        "raw tables are missing."
                    )
                    print(
                        "Verify sql/02_create_raw_tables.sql and the current "
                        "database/schema configuration."
                    )
                else:
                    print("\nAll expected raw tables are present.")

                return True

    except Exception as exc:
        # The exception may include connection details. Do not print the
        # full DATABASE_URL; print only the exception message.
        print("CONNECTION FAILED")
        print(f"Error type : {type(exc).__name__}")
        print(f"Error      : {exc}")
        print()
        print("Check the following:")
        print("  1. PostgreSQL is running and reachable.")
        print("  2. DATABASE_URL in .env points to the intended database.")
        print("  3. The database name, username, and password are correct.")
        print("  4. The host/port are correct (Docker port mapping may differ).")
        print("  5. The user has permission to connect to the database.")
        return False


def main() -> int:
    """Run the connection check and return an appropriate exit code."""
    database_url = get_database_url()

    if not database_url:
        print("ERROR: DATABASE_URL is not set.")
        print()
        print(f"Expected location: {ENV_FILE}")
        print("Add a line like the following to .env, using your real settings:")
        print(
            "DATABASE_URL=postgresql://YOUR_USER:YOUR_PASSWORD@localhost:5432/YOUR_DATABASE"
        )
        print()
        print("Do not commit .env to Git.")
        return 2

    success = check_connection(database_url)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
