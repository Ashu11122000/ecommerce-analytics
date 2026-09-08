"""
Generate realistic mock e-commerce RAW data.

Output:
    sql/03_insert_raw_data.sql

The generated SQL loads:
    - customers
    - products
    - orders
    - order_items
    - payments
    - shipments
    - returns

The data includes:
    - different business dates
    - different ingestion batches
    - realistic relationships
    - historical product prices
    - payment states
    - shipment states
    - returns
    - late-arriving records
    - updated records
    - NULL values
    - controlled data-quality scenarios
    - reproducible data using a fixed random seed

Timestamp strategy:
    - event/business timestamp = when the business event happened
    - updated_at = when the source record was last updated
    - ingested_at = when the record arrived in the RAW layer

All normal generated timestamps are constrained to the
DATA_AS_OF date.

This script uses only Python standard-library modules.
"""

from datetime import datetime, date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import random


# ============================================================
# CONFIGURATION
# ============================================================

RANDOM_SEED = 42

# The simulated "current" date of our source/warehouse system.
# This prevents accidental future timestamps.
DATA_AS_OF = datetime(2026, 9, 8, 23, 59, 59)

CUSTOMER_COUNT = 120
PRODUCT_COUNT = 500
ORDER_COUNT = 320

MIN_ORDER_ITEMS = 1
MAX_ORDER_ITEMS = 3

PAYMENT_COUNT = 320
SHIPMENT_COUNT = 290
RETURN_COUNT = 30

OUTPUT_FILE = (
    Path(__file__).resolve().parent.parent
    / "sql"
    / "03_insert_raw_data.sql"
)

random.seed(RANDOM_SEED)


# ============================================================
# REFERENCE DATA
# ============================================================

FIRST_NAMES = [
    "Aarav",
    "Vivaan",
    "Aditya",
    "Arjun",
    "Rahul",
    "Rohan",
    "Karan",
    "Vikram",
    "Ananya",
    "Priya",
    "Sneha",
    "Neha",
    "Isha",
    "Kavya",
    "Meera",
    "Pooja",
]

LAST_NAMES = [
    "Sharma",
    "Patel",
    "Kumar",
    "Singh",
    "Verma",
    "Gupta",
    "Mehta",
    "Joshi",
    "Shah",
    "Reddy",
    "Nair",
    "Iyer",
]

LOCATIONS = [
    ("Mumbai", "Maharashtra", "400001"),
    ("Pune", "Maharashtra", "411001"),
    ("Bengaluru", "Karnataka", "560001"),
    ("Hyderabad", "Telangana", "500001"),
    ("Chennai", "Tamil Nadu", "600001"),
    ("Delhi", "Delhi", "110001"),
    ("Jaipur", "Rajasthan", "302001"),
    ("Ahmedabad", "Gujarat", "380001"),
    ("Kolkata", "West Bengal", "700001"),
    ("Lucknow", "Uttar Pradesh", "226001"),
]

CATEGORIES = {
    "Electronics": [
        "Mobile",
        "Laptop",
        "Tablet",
        "Headphones",
        "Smartwatch",
    ],
    "Home": [
        "Furniture",
        "Kitchen",
        "Decor",
        "Storage",
        "Lighting",
    ],
    "Fashion": [
        "Men",
        "Women",
        "Footwear",
        "Accessories",
        "Sportswear",
    ],
    "Beauty": [
        "Skincare",
        "Haircare",
        "Makeup",
        "Fragrance",
    ],
    "Books": [
        "Fiction",
        "Non Fiction",
        "Technology",
        "Business",
        "Education",
    ],
}

BRANDS = [
    "Nova",
    "UrbanX",
    "Prime",
    "Vertex",
    "Apex",
    "Zenith",
    "Orbit",
    "Fusion",
    "Pulse",
    "Aura",
]

CUSTOMER_SEGMENTS = [
    "Premium",
    "Regular",
    "Occasional",
    "New",
]

CUSTOMER_STATUSES = [
    "Active",
    "Inactive",
]

ORDER_STATUSES = [
    "Pending",
    "Confirmed",
    "Shipped",
    "Delivered",
    "Cancelled",
    "Returned",
]

PAYMENT_STATUSES = [
    "Paid",
    "Pending",
    "Failed",
    "Refunded",
]

PAYMENT_METHODS = [
    "UPI",
    "Credit Card",
    "Debit Card",
    "Net Banking",
    "Cash on Delivery",
]

SHIPPING_METHODS = [
    "Standard",
    "Express",
    "Same Day",
]

SALES_CHANNELS = [
    "Website",
    "Mobile App",
    "Marketplace",
    "Store",
]

SHIPMENT_STATUSES = [
    "Processing",
    "Shipped",
    "In Transit",
    "Delivered",
    "Delayed",
    "Cancelled",
]

RETURN_REASONS = [
    "Damaged",
    "Wrong Product",
    "Size Issue",
    "Customer Changed Mind",
    "Defective",
    "Late Delivery",
]

RETURN_STATUSES = [
    "Requested",
    "Approved",
    "Completed",
    "Rejected",
]

CURRENCY = "INR"


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def random_date(start_date: date, end_date: date) -> date:
    """Return a random date between start_date and end_date."""

    if start_date > end_date:
        raise ValueError(
            "start_date cannot be after end_date."
        )

    days = (end_date - start_date).days

    return start_date + timedelta(
        days=random.randint(0, days)
    )


def random_datetime(
    start_date: date,
    end_date: date,
) -> datetime:
    """
    Return a random datetime between two dates.

    The generated datetime will never be later than
    DATA_AS_OF.
    """

    if start_date > end_date:
        raise ValueError(
            "start_date cannot be after end_date."
        )

    selected_date = random_date(
        start_date,
        end_date,
    )

    hour = random.randint(8, 21)
    minute = random.randint(0, 59)
    second = random.randint(0, 59)

    generated_datetime = datetime(
        selected_date.year,
        selected_date.month,
        selected_date.day,
        hour,
        minute,
        second,
    )

    return min(
        generated_datetime,
        DATA_AS_OF,
    )


def add_hours_capped(
    base_datetime: datetime,
    min_hours: int,
    max_hours: int,
) -> datetime:
    """
    Add a random number of hours to a timestamp.

    The result is capped at DATA_AS_OF so we do not create
    accidental future timestamps.
    """

    generated_datetime = (
        base_datetime
        + timedelta(
            hours=random.randint(
                min_hours,
                max_hours,
            )
        )
    )

    return min(
        generated_datetime,
        DATA_AS_OF,
    )


def add_days_capped(
    base_datetime: datetime,
    min_days: int,
    max_days: int,
) -> datetime:
    """
    Add a random number of days to a timestamp.

    The result is capped at DATA_AS_OF.
    """

    generated_datetime = (
        base_datetime
        + timedelta(
            days=random.randint(
                min_days,
                max_days,
            )
        )
    )

    return min(
        generated_datetime,
        DATA_AS_OF,
    )


def money(value) -> Decimal:
    """Convert a value to a two-decimal monetary value."""

    return Decimal(str(value)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )


def sql_string(value):
    """
    Convert Python values into SQL literals.

    Strings are escaped.
    None becomes SQL NULL.
    Dates and datetimes are quoted.
    """

    if value is None:
        return "NULL"

    if isinstance(value, Decimal):
        return str(value)

    if isinstance(value, (int, float)):
        return str(value)

    if isinstance(value, (date, datetime)):
        return f"'{value}'"

    value = str(value).replace(
        "'",
        "''",
    )

    return f"'{value}'"


def sql_insert(
    table_name,
    columns,
    rows,
):
    """Generate one INSERT statement per row."""

    statements = []

    if not rows:
        return statements

    column_sql = ", ".join(columns)

    for row in rows:

        values = ", ".join(
            sql_string(value)
            for value in row
        )

        statements.append(
            f"INSERT INTO raw.{table_name} "
            f"({column_sql}) "
            f"VALUES ({values});"
        )

    return statements


# ============================================================
# CUSTOMERS
# ============================================================

def generate_customers():

    customers = []

    start_date = date(2022, 1, 1)
    end_date = DATA_AS_OF.date()

    for customer_id in range(
        1,
        CUSTOMER_COUNT + 1,
    ):

        first_name = random.choice(
            FIRST_NAMES
        )

        last_name = random.choice(
            LAST_NAMES
        )

        customer_name = (
            f"{first_name} {last_name}"
        )

        email = (
            f"{first_name.lower()}."
            f"{last_name.lower()}."
            f"{customer_id}"
            f"@example.com"
        )

        phone = (
            f"9{random.randint(100000000, 999999999)}"
        )

        gender = random.choice(
            [
                "Male",
                "Female",
                "Other",
            ]
        )

        date_of_birth = random_date(
            date(1970, 1, 1),
            date(2004, 12, 31),
        )

        city, state, postal_code = random.choice(
            LOCATIONS
        )

        country = "India"

        customer_segment = random.choice(
            CUSTOMER_SEGMENTS
        )

        customer_status = random.choice(
            CUSTOMER_STATUSES
        )

        signup_date = random_date(
            start_date,
            end_date,
        )

        # Updated at must be after signup_date
        # but cannot exceed DATA_AS_OF.
        signup_datetime = datetime.combine(
            signup_date,
            datetime.min.time(),
        )

        max_update_datetime = min(
            signup_datetime
            + timedelta(days=365),
            DATA_AS_OF,
        )

        updated_at = signup_datetime

        if max_update_datetime > signup_datetime:

            available_hours = int(
                (
                    max_update_datetime
                    - signup_datetime
                ).total_seconds()
                // 3600
            )

            updated_at = (
                signup_datetime
                + timedelta(
                    hours=random.randint(
                        0,
                        available_hours,
                    )
                )
            )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            48,
        )

        # Controlled NULL scenario.
        if customer_id % 17 == 0:
            phone = None

        customers.append(
            (
                customer_id,
                customer_name,
                email,
                phone,
                gender,
                date_of_birth,
                city,
                state,
                country,
                postal_code,
                customer_segment,
                customer_status,
                signup_date,
                updated_at,
                ingested_at,
            )
        )

    return customers


# ============================================================
# PRODUCTS
# ============================================================

def generate_products():

    products = []

    product_start_date = date(
        2022,
        1,
        1,
    )

    product_end_date = DATA_AS_OF.date()

    category_names = list(
        CATEGORIES.keys()
    )

    for product_id in range(
        1,
        PRODUCT_COUNT + 1,
    ):

        category = random.choice(
            category_names
        )

        subcategory = random.choice(
            CATEGORIES[category]
        )

        brand = random.choice(
            BRANDS
        )

        product_name = (
            f"{brand} "
            f"{subcategory.replace(' ', '')} "
            f"Product {product_id}"
        )

        supplier_id = random.randint(
            1,
            50,
        )

        cost_price = money(
            random.uniform(
                200,
                20000,
            )
        )

        margin = random.uniform(
            0.10,
            0.45,
        )

        selling_price = money(
            cost_price
            * Decimal(
                str(1 + margin)
            )
        )

        stock_quantity = random.randint(
            0,
            500,
        )

        reorder_level = random.randint(
            10,
            100,
        )

        product_status = random.choice(
            [
                "Active",
                "Inactive",
                "Discontinued",
            ]
        )

        launch_date = random_date(
            product_start_date,
            product_end_date,
        )

        updated_at = random_datetime(
            launch_date,
            product_end_date,
        )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            48,
        )

        products.append(
            (
                product_id,
                product_name,
                category,
                subcategory,
                brand,
                supplier_id,
                cost_price,
                selling_price,
                stock_quantity,
                reorder_level,
                product_status,
                launch_date,
                updated_at,
                ingested_at,
            )
        )

    return products


# ============================================================
# ORDERS
# ============================================================

def generate_orders():

    orders = []

    order_start_date = date(
        2026,
        1,
        1,
    )

    order_end_date = DATA_AS_OF.date()

    for order_id in range(
        1,
        ORDER_COUNT + 1,
    ):

        customer_id = random.randint(
            1,
            CUSTOMER_COUNT,
        )

        order_date = random_datetime(
            order_start_date,
            order_end_date,
        )

        order_status = random.choices(
            ORDER_STATUSES,
            weights=[
                5,
                10,
                10,
                55,
                8,
                12,
            ],
        )[0]

        payment_status = random.choices(
            [
                "Paid",
                "Pending",
                "Failed",
            ],
            weights=[
                80,
                10,
                10,
            ],
        )[0]

        shipping_method = random.choice(
            SHIPPING_METHODS
        )

        shipping_cost = money(
            random.uniform(
                40,
                250,
            )
        )

        discount_amount = money(
            random.uniform(
                0,
                1000,
            )
        )

        tax_amount = money(
            random.uniform(
                50,
                2500,
            )
        )

        sales_channel = random.choice(
            SALES_CHANNELS
        )

        updated_at = add_hours_capped(
            order_date,
            1,
            72,
        )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            48,
        )

        orders.append(
            {
                "order_id": order_id,
                "customer_id": customer_id,
                "order_date": order_date,
                "order_status": order_status,
                "payment_status": payment_status,
                "shipping_method": shipping_method,
                "shipping_cost": shipping_cost,
                "discount_amount": discount_amount,
                "tax_amount": tax_amount,
                "total_amount": money(0),
                "sales_channel": sales_channel,
                "currency": CURRENCY,
                "updated_at": updated_at,
                "ingested_at": ingested_at,
            }
        )

    # --------------------------------------------------------
    # Explicit late-arriving order
    # --------------------------------------------------------
    #
    # Business event:
    #   2026-08-01
    #
    # Source updated:
    #   2026-09-06
    #
    # Warehouse received it:
    #   2026-09-07
    #
    # This is intentionally created to demonstrate
    # late-arriving data.
    # --------------------------------------------------------

    late_order = orders[-1]

    late_order["order_date"] = datetime(
        2026,
        8,
        1,
        10,
        0,
        0,
    )

    late_order["updated_at"] = datetime(
        2026,
        9,
        6,
        9,
        30,
        0,
    )

    late_order["ingested_at"] = datetime(
        2026,
        9,
        7,
        8,
        15,
        0,
    )

    # --------------------------------------------------------
    # Explicit updated-record scenario
    # --------------------------------------------------------

    updated_order = orders[9]

    updated_order["order_status"] = "Delivered"

    updated_order["updated_at"] = datetime(
        2026,
        9,
        5,
        11,
        0,
        0,
    )

    updated_order["ingested_at"] = datetime(
        2026,
        9,
        5,
        12,
        0,
        0,
    )

    return orders


# ============================================================
# ORDER ITEMS
# ============================================================

def generate_order_items(
    orders,
    products,
):

    order_items = []

    order_item_id = 1001

    for order in orders:

        item_count = random.randint(
            MIN_ORDER_ITEMS,
            MAX_ORDER_ITEMS,
        )

        selected_products = random.sample(
            products,
            item_count,
        )

        order_subtotal = Decimal(
            "0.00"
        )

        for product in selected_products:

            product_id = product[0]

            # selling_price is index 7.
            #
            # Important:
            # This represents the historical price
            # actually charged when the customer ordered.
            historical_price = product[7]

            quantity = random.randint(
                1,
                5,
            )

            discount_amount = money(
                random.uniform(
                    0,
                    300,
                )
            )

            tax_amount = money(
                random.uniform(
                    0,
                    500,
                )
            )

            line_total = money(
                historical_price * quantity
                - discount_amount
                + tax_amount
            )

            returned_quantity = 0

            updated_at = add_hours_capped(
                order["updated_at"],
                0,
                2,
            )

            ingested_at = add_hours_capped(
                updated_at,
                1,
                24,
            )

            order_items.append(
                {
                    "order_item_id": order_item_id,
                    "order_id": order["order_id"],
                    "product_id": product_id,
                    "quantity": quantity,
                    "unit_price": historical_price,
                    "discount_amount": discount_amount,
                    "tax_amount": tax_amount,
                    "line_total": line_total,
                    "returned_quantity": returned_quantity,
                    "updated_at": updated_at,
                    "ingested_at": ingested_at,
                }
            )

            order_subtotal += line_total

            order_item_id += 1

        order["total_amount"] = money(
            order_subtotal
            + order["shipping_cost"]
        )

    # --------------------------------------------------------
    # Controlled data-quality issue #1
    # --------------------------------------------------------
    #
    # Negative quantity.
    #
    # This is intentionally allowed into RAW so that the
    # Silver layer can demonstrate data-quality validation.
    # --------------------------------------------------------

    order_items[20]["quantity"] = -1

    # --------------------------------------------------------
    # Controlled data-quality issue #2
    # --------------------------------------------------------
    #
    # Incorrect line total.
    #
    # This allows us to demonstrate reconciliation logic later.
    # --------------------------------------------------------

    order_items[40]["line_total"] = money(
        order_items[40]["line_total"]
        + 500
    )

    # --------------------------------------------------------
    # Recalculate order totals from final source values.
    # --------------------------------------------------------

    totals = {}

    for item in order_items:

        order_id = item["order_id"]

        totals.setdefault(
            order_id,
            Decimal("0.00"),
        )

        totals[order_id] += (
            item["line_total"]
        )

    for order in orders:

        order["total_amount"] = money(
            totals[
                order["order_id"]
            ]
            + order["shipping_cost"]
        )

    return order_items


# ============================================================
# PAYMENTS
# ============================================================

def generate_payments(orders):

    payments = []

    payment_id = 1

    for order in orders:

        payment_status = (
            order["payment_status"]
        )

        amount = money(
            order["total_amount"]
        )

        payment_date = add_hours_capped(
            order["order_date"],
            1,
            12,
        )

        updated_at = add_hours_capped(
            payment_date,
            1,
            24,
        )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            24,
        )

        transaction_reference = (
            f"TXN-{payment_id:06d}"
        )

        payments.append(
            (
                payment_id,
                order["order_id"],
                payment_date,
                random.choice(
                    PAYMENT_METHODS
                ),
                payment_status,
                amount,
                transaction_reference,
                updated_at,
                ingested_at,
            )
        )

        payment_id += 1

    return payments


# ============================================================
# SHIPMENTS
# ============================================================

def generate_shipments(orders):

    shipments = []

    shipment_id = 1

    eligible_orders = [
        order
        for order in orders
        if order["order_status"]
        not in [
            "Cancelled",
            "Pending",
        ]
    ]

    selected_orders = random.sample(
        eligible_orders,
        min(
            SHIPMENT_COUNT,
            len(eligible_orders),
        ),
    )

    for order in selected_orders:

        shipped_at = add_days_capped(
            order["order_date"],
            1,
            3,
        )

        shipment_status = random.choices(
            SHIPMENT_STATUSES,
            weights=[
                5,
                10,
                10,
                55,
                15,
                5,
            ],
        )[0]

        # A delivered shipment requires a delivery timestamp.
        if shipment_status == "Delivered":

            delivered_at = add_days_capped(
                shipped_at,
                1,
                7,
            )

        else:

            delivered_at = None

        city, state, _ = random.choice(
            LOCATIONS
        )

        if delivered_at:

            updated_base = delivered_at

        else:

            updated_base = shipped_at

        updated_at = add_hours_capped(
            updated_base,
            1,
            24,
        )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            24,
        )

        shipments.append(
            (
                shipment_id,
                order["order_id"],
                order["shipping_method"],
                shipment_status,
                shipped_at,
                delivered_at,
                city,
                state,
                updated_at,
                ingested_at,
            )
        )

        shipment_id += 1

    return shipments


# ============================================================
# RETURNS
# ============================================================

def generate_returns(order_items):

    returns = []

    eligible_items = [
        item
        for item in order_items
        if item["quantity"] > 0
    ]

    selected_items = random.sample(
        eligible_items,
        min(
            RETURN_COUNT,
            len(eligible_items),
        ),
    )

    return_id = 1

    for item in selected_items:

        return_quantity = random.randint(
            1,
            item["quantity"],
        )

        # Returns happen after the order-item event.
        #
        # add_days_capped prevents accidental future dates.
        return_date = add_days_capped(
            item["updated_at"],
            2,
            30,
        )

        refund_amount = money(
            item["unit_price"]
            * return_quantity
        )

        return_status = random.choice(
            RETURN_STATUSES
        )

        updated_at = add_hours_capped(
            return_date,
            1,
            48,
        )

        ingested_at = add_hours_capped(
            updated_at,
            1,
            24,
        )

        returns.append(
            (
                return_id,
                item["order_item_id"],
                return_date,
                random.choice(
                    RETURN_REASONS
                ),
                return_quantity,
                refund_amount,
                return_status,
                updated_at,
                ingested_at,
            )
        )

        return_id += 1

    return returns


# ============================================================
# SQL GENERATION
# ============================================================

def generate_sql(
    customers,
    products,
    orders,
    order_items,
    payments,
    shipments,
    returns,
):

    sql = []

    # --------------------------------------------------------
    # Header
    # --------------------------------------------------------

    sql.append(
        "-- =====================================================\n"
        "-- GENERATED RAW DATA\n"
        "-- Generated by scripts/generate_raw_data.py\n"
        "-- =====================================================\n"
    )

    sql.append(
        "-- WARNING: This resets the RAW tables before loading\n"
        "-- the generated dataset.\n"
    )

    # --------------------------------------------------------
    # Reset RAW tables
    # --------------------------------------------------------

    sql.append(
        "TRUNCATE TABLE "
        "raw.returns, "
        "raw.shipments, "
        "raw.payments, "
        "raw.order_items, "
        "raw.orders, "
        "raw.products, "
        "raw.customers "
        "RESTART IDENTITY CASCADE;\n"
    )

    # --------------------------------------------------------
    # Customers
    # --------------------------------------------------------

    customer_columns = [
        "customer_id",
        "customer_name",
        "email",
        "phone",
        "gender",
        "date_of_birth",
        "city",
        "state",
        "country",
        "postal_code",
        "customer_segment",
        "customer_status",
        "signup_date",
        "updated_at",
        "ingested_at",
    ]

    customer_sql = sql_insert(
        "customers",
        customer_columns,
        customers,
    )

    sql.extend(customer_sql)

    # --------------------------------------------------------
    # Products
    # --------------------------------------------------------

    product_columns = [
        "product_id",
        "product_name",
        "category",
        "subcategory",
        "brand",
        "supplier_id",
        "cost_price",
        "selling_price",
        "stock_quantity",
        "reorder_level",
        "product_status",
        "launch_date",
        "updated_at",
        "ingested_at",
    ]

    product_sql = sql_insert(
        "products",
        product_columns,
        products,
    )

    sql.extend(product_sql)

    # --------------------------------------------------------
    # Orders
    # --------------------------------------------------------

    order_columns = [
        "order_id",
        "customer_id",
        "order_date",
        "order_status",
        "payment_status",
        "shipping_method",
        "shipping_cost",
        "discount_amount",
        "tax_amount",
        "total_amount",
        "sales_channel",
        "currency",
        "updated_at",
        "ingested_at",
    ]

    order_rows = [
        (
            order["order_id"],
            order["customer_id"],
            order["order_date"],
            order["order_status"],
            order["payment_status"],
            order["shipping_method"],
            order["shipping_cost"],
            order["discount_amount"],
            order["tax_amount"],
            order["total_amount"],
            order["sales_channel"],
            order["currency"],
            order["updated_at"],
            order["ingested_at"],
        )
        for order in orders
    ]

    order_sql = sql_insert(
        "orders",
        order_columns,
        order_rows,
    )

    sql.extend(order_sql)

    # --------------------------------------------------------
    # Order Items
    # --------------------------------------------------------

    order_item_columns = [
        "order_item_id",
        "order_id",
        "product_id",
        "quantity",
        "unit_price",
        "discount_amount",
        "tax_amount",
        "line_total",
        "returned_quantity",
        "updated_at",
        "ingested_at",
    ]

    order_item_rows = [
        (
            item["order_item_id"],
            item["order_id"],
            item["product_id"],
            item["quantity"],
            item["unit_price"],
            item["discount_amount"],
            item["tax_amount"],
            item["line_total"],
            item["returned_quantity"],
            item["updated_at"],
            item["ingested_at"],
        )
        for item in order_items
    ]

    order_item_sql = sql_insert(
        "order_items",
        order_item_columns,
        order_item_rows,
    )

    sql.extend(order_item_sql)

    # --------------------------------------------------------
    # Payments
    # --------------------------------------------------------

    payment_columns = [
        "payment_id",
        "order_id",
        "payment_date",
        "payment_method",
        "payment_status",
        "amount",
        "transaction_reference",
        "updated_at",
        "ingested_at",
    ]

    payment_sql = sql_insert(
        "payments",
        payment_columns,
        payments,
    )

    sql.extend(payment_sql)

    # --------------------------------------------------------
    # Shipments
    # --------------------------------------------------------

    shipment_columns = [
        "shipment_id",
        "order_id",
        "shipping_method",
        "shipment_status",
        "shipped_at",
        "delivered_at",
        "delivery_city",
        "delivery_state",
        "updated_at",
        "ingested_at",
    ]

    shipment_sql = sql_insert(
        "shipments",
        shipment_columns,
        shipments,
    )

    sql.extend(shipment_sql)

    # --------------------------------------------------------
    # Returns
    # --------------------------------------------------------

    return_columns = [
        "return_id",
        "order_item_id",
        "return_date",
        "return_reason",
        "return_quantity",
        "refund_amount",
        "return_status",
        "updated_at",
        "ingested_at",
    ]

    return_sql = sql_insert(
        "returns",
        return_columns,
        returns,
    )

    sql.extend(return_sql)

    # --------------------------------------------------------
    # Footer
    # --------------------------------------------------------

    sql.append(
        "\n-- =====================================================\n"
        "-- END OF GENERATED DATA\n"
        "-- =====================================================\n"
    )

    # ========================================================
    # SQL GENERATION VALIDATION
    # ========================================================

    expected_counts = {
        "customers": len(customers),
        "products": len(products),
        "orders": len(orders),
        "order_items": len(order_items),
        "payments": len(payments),
        "shipments": len(shipments),
        "returns": len(returns),
    }

    actual_counts = {
        "customers": len(customer_sql),
        "products": len(product_sql),
        "orders": len(order_sql),
        "order_items": len(order_item_sql),
        "payments": len(payment_sql),
        "shipments": len(shipment_sql),
        "returns": len(return_sql),
    }

    print("\nSQL generation validation:")
    print("-" * 55)

    for table_name in expected_counts:

        expected = expected_counts[
            table_name
        ]

        actual = actual_counts[
            table_name
        ]

        print(
            f"{table_name:<15}"
            f" expected={expected:<4}"
            f" generated={actual:<4}"
        )

        if expected != actual:

            raise ValueError(
                f"SQL generation failed for "
                f"{table_name}: "
                f"expected {expected} INSERT statements, "
                f"but generated {actual}."
            )

    print("-" * 55)

    print(
        f"Total SQL statements generated: "
        f"{len(sql)}"
    )

    return "\n".join(sql)


# ============================================================
# TIMESTAMP VALIDATION
# ============================================================

def validate_timestamps(
    customers,
    products,
    orders,
    order_items,
    payments,
    shipments,
    returns,
):
    """
    Validate that generated timestamps do not exceed
    DATA_AS_OF.

    Also validate the basic timestamp ordering:

        event
          <= updated_at
          <= ingested_at
          <= DATA_AS_OF
    """

    print("\nTimestamp validation:")
    print("-" * 55)

    violations = []

    # --------------------------------------------------------
    # Customers
    # --------------------------------------------------------

    for customer in customers:

        updated_at = customer[13]
        ingested_at = customer[14]

        if updated_at > DATA_AS_OF:
            violations.append(
                f"customer {customer[0]} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"customer {customer[0]} ingested_at"
            )

        if ingested_at < updated_at:
            violations.append(
                f"customer {customer[0]} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Products
    # --------------------------------------------------------

    for product in products:

        updated_at = product[12]
        ingested_at = product[13]

        if updated_at > DATA_AS_OF:
            violations.append(
                f"product {product[0]} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"product {product[0]} ingested_at"
            )

        if ingested_at < updated_at:
            violations.append(
                f"product {product[0]} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Orders
    # --------------------------------------------------------

    for order in orders:

        order_date = order["order_date"]
        updated_at = order["updated_at"]
        ingested_at = order["ingested_at"]

        if order_date > DATA_AS_OF:
            violations.append(
                f"order {order['order_id']} order_date"
            )

        if updated_at > DATA_AS_OF:
            violations.append(
                f"order {order['order_id']} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"order {order['order_id']} ingested_at"
            )

        if updated_at < order_date:
            violations.append(
                f"order {order['order_id']} "
                f"updated_at < order_date"
            )

        if ingested_at < updated_at:
            violations.append(
                f"order {order['order_id']} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Order Items
    # --------------------------------------------------------

    for item in order_items:

        updated_at = item["updated_at"]
        ingested_at = item["ingested_at"]

        if updated_at > DATA_AS_OF:
            violations.append(
                f"order_item "
                f"{item['order_item_id']} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"order_item "
                f"{item['order_item_id']} ingested_at"
            )

        if ingested_at < updated_at:
            violations.append(
                f"order_item "
                f"{item['order_item_id']} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Payments
    # --------------------------------------------------------

    for payment in payments:

        payment_date = payment[2]
        updated_at = payment[7]
        ingested_at = payment[8]

        if payment_date > DATA_AS_OF:
            violations.append(
                f"payment {payment[0]} payment_date"
            )

        if updated_at > DATA_AS_OF:
            violations.append(
                f"payment {payment[0]} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"payment {payment[0]} ingested_at"
            )

        if updated_at < payment_date:
            violations.append(
                f"payment {payment[0]} "
                f"updated_at < payment_date"
            )

        if ingested_at < updated_at:
            violations.append(
                f"payment {payment[0]} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Shipments
    # --------------------------------------------------------

    for shipment in shipments:

        shipped_at = shipment[4]
        delivered_at = shipment[5]
        updated_at = shipment[8]
        ingested_at = shipment[9]

        if shipped_at > DATA_AS_OF:
            violations.append(
                f"shipment {shipment[0]} shipped_at"
            )

        if delivered_at and delivered_at > DATA_AS_OF:
            violations.append(
                f"shipment {shipment[0]} delivered_at"
            )

        if updated_at > DATA_AS_OF:
            violations.append(
                f"shipment {shipment[0]} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"shipment {shipment[0]} ingested_at"
            )

        if (
            delivered_at
            and delivered_at < shipped_at
        ):
            violations.append(
                f"shipment {shipment[0]} "
                f"delivered_at < shipped_at"
            )

        if updated_at < shipped_at:
            violations.append(
                f"shipment {shipment[0]} "
                f"updated_at < shipped_at"
            )

        if ingested_at < updated_at:
            violations.append(
                f"shipment {shipment[0]} "
                f"ingested_at < updated_at"
            )

    # --------------------------------------------------------
    # Returns
    # --------------------------------------------------------

    for return_record in returns:

        return_date = return_record[2]
        updated_at = return_record[7]
        ingested_at = return_record[8]

        if return_date > DATA_AS_OF:
            violations.append(
                f"return {return_record[0]} return_date"
            )

        if updated_at > DATA_AS_OF:
            violations.append(
                f"return {return_record[0]} updated_at"
            )

        if ingested_at > DATA_AS_OF:
            violations.append(
                f"return {return_record[0]} ingested_at"
            )

        if updated_at < return_date:
            violations.append(
                f"return {return_record[0]} "
                f"updated_at < return_date"
            )

        if ingested_at < updated_at:
            violations.append(
                f"return {return_record[0]} "
                f"ingested_at < updated_at"
            )

    if violations:

        print(
            f"FAILED: {len(violations)} "
            f"timestamp violations found."
        )

        for violation in violations[:20]:
            print(
                f"  - {violation}"
            )

        raise ValueError(
            "Timestamp validation failed."
        )

    print(
        f"All timestamps are <= "
        f"{DATA_AS_OF}."
    )

    print(
        "Timestamp ordering validation passed."
    )


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 60)
    print("E-COMMERCE RAW DATA GENERATOR")
    print("=" * 60)

    print(
        f"\nData as of: "
        f"{DATA_AS_OF}"
    )

    print(
        f"Random seed: "
        f"{RANDOM_SEED}"
    )

    # --------------------------------------------------------
    # Generate source datasets
    # --------------------------------------------------------

    print("\nGenerating customers...")

    customers = generate_customers()

    print("Generating products...")

    products = generate_products()

    print("Generating orders...")

    orders = generate_orders()

    print("Generating order items...")

    order_items = generate_order_items(
        orders,
        products,
    )

    print("Generating payments...")

    payments = generate_payments(
        orders
    )

    print("Generating shipments...")

    shipments = generate_shipments(
        orders
    )

    print("Generating returns...")

    returns = generate_returns(
        order_items
    )

    # --------------------------------------------------------
    # Validate high-level counts
    # --------------------------------------------------------

    if len(customers) != CUSTOMER_COUNT:

        raise ValueError(
            f"Expected {CUSTOMER_COUNT} customers, "
            f"got {len(customers)}."
        )

    if len(products) != PRODUCT_COUNT:

        raise ValueError(
            f"Expected {PRODUCT_COUNT} products, "
            f"got {len(products)}."
        )

    if len(orders) != ORDER_COUNT:

        raise ValueError(
            f"Expected {ORDER_COUNT} orders, "
            f"got {len(orders)}."
        )

    if len(order_items) < ORDER_COUNT:

        raise ValueError(
            "Every order should have at least "
            "one order item."
        )

    if len(payments) != PAYMENT_COUNT:

        raise ValueError(
            f"Expected {PAYMENT_COUNT} payments, "
            f"got {len(payments)}."
        )

    if not (
        280
        <= len(shipments)
        <= 300
    ):

        raise ValueError(
            "Expected shipments between "
            "280 and 300."
        )

    if not (
        20
        <= len(returns)
        <= 40
    ):

        raise ValueError(
            "Expected returns between "
            "20 and 40."
        )

    # --------------------------------------------------------
    # Validate timestamps
    # --------------------------------------------------------

    validate_timestamps(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # --------------------------------------------------------
    # Generate SQL
    # --------------------------------------------------------

    sql = generate_sql(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # --------------------------------------------------------
    # Write SQL file
    # --------------------------------------------------------

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    OUTPUT_FILE.write_text(
        sql,
        encoding="utf-8",
    )

    # --------------------------------------------------------
    # Final output
    # --------------------------------------------------------

    print("\n" + "=" * 60)
    print("DATA GENERATION COMPLETE")
    print("=" * 60)

    print(
        f"\nCustomers   : "
        f"{len(customers)}"
    )

    print(
        f"Products    : "
        f"{len(products)}"
    )

    print(
        f"Orders      : "
        f"{len(orders)}"
    )

    print(
        f"Order Items : "
        f"{len(order_items)}"
    )

    print(
        f"Payments    : "
        f"{len(payments)}"
    )

    print(
        f"Shipments   : "
        f"{len(shipments)}"
    )

    print(
        f"Returns     : "
        f"{len(returns)}"
    )

    print(
        "\nSQL file:"
    )

    print(
        OUTPUT_FILE
    )

    print(
        "\nRandom seed:"
    )

    print(
        RANDOM_SEED
    )

    print(
        "\nData as of:"
    )

    print(
        DATA_AS_OF
    )

    print(
        "\nThe generated SQL is ready "
        "to be validated before loading."
    )


if __name__ == "__main__":
    main()