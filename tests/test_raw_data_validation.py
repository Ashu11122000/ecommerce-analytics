
"""
Validate raw e-commerce tables in PostgreSQL.

Expected tables:
    raw.customers
    raw.products
    raw.orders
    raw.order_items
    raw.payments
    raw.shipments
    raw.returns

Run from the project root:
    python -m pytest tests/test_raw_data_validation.py -v

Requires:
    pytest
    sqlalchemy
    psycopg
    DATABASE_URL environment variable
"""

import os

import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import SQLAlchemyError


EXPECTED_TABLES = {
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
    "shipments",
    "returns",
}


@pytest.fixture(scope="module")
def engine():
    """Create a database connection using DATABASE_URL."""
    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        pytest.skip("DATABASE_URL is not configured.")

    db_engine = create_engine(database_url)

    try:
        with db_engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        db_engine.dispose()
        pytest.fail(f"Could not connect to PostgreSQL: {exc}")

    yield db_engine
    db_engine.dispose()


@pytest.fixture(scope="module")
def available_tables(engine):
    """Return table names available in the raw schema."""
    inspector = inspect(engine)
    return set(inspector.get_table_names(schema="raw"))


def test_raw_schema_contains_expected_tables(available_tables):
    """All expected raw tables should exist."""
    missing_tables = EXPECTED_TABLES - available_tables

    assert not missing_tables, (
        f"Missing tables in schema 'raw': {sorted(missing_tables)}"
    )


@pytest.mark.parametrize("table_name", sorted(EXPECTED_TABLES))
def test_raw_tables_are_not_empty(engine, available_tables, table_name):
    """Each expected raw table should contain at least one row."""
    if table_name not in available_tables:
        pytest.skip(f"raw.{table_name} does not exist.")

    with engine.connect() as connection:
        row_count = connection.execute(
            text(f'SELECT COUNT(*) FROM raw."{table_name}"')
        ).scalar_one()

    assert row_count > 0, f"raw.{table_name} contains no rows."


@pytest.mark.parametrize(
    ("table_name", "id_column"),
    [
        ("customers", "customer_id"),
        ("products", "product_id"),
        ("orders", "order_id"),
        ("order_items", "order_item_id"),
        ("payments", "payment_id"),
        ("shipments", "shipment_id"),
        ("returns", "return_id"),
    ],
)
def test_raw_primary_ids_are_not_null(
    engine, available_tables, table_name, id_column
):
    """Identifier columns should not contain NULL values."""
    if table_name not in available_tables:
        pytest.skip(f"raw.{table_name} does not exist.")

    columns = {
        column["name"]
        for column in inspect(engine).get_columns(table_name, schema="raw")
    }

    if id_column not in columns:
        pytest.fail(
            f"Expected column raw.{table_name}.{id_column} was not found. "
            "Update this test to match the actual schema."
        )

    query = text(
        f'SELECT COUNT(*) FROM raw."{table_name}" '
        f'WHERE "{id_column}" IS NULL'
    )

    with engine.connect() as connection:
        null_count = connection.execute(query).scalar_one()

    assert null_count == 0, (
        f"raw.{table_name}.{id_column} contains "
        f"{null_count} NULL value(s)."
    )
