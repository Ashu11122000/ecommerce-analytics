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
    - payment attempts
    - shipment states
    - returns
    - late-arriving records
    - controlled data-quality scenarios

This script uses only Python standard-library modules.
"""

from datetime import datetime, date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import random


RANDOM_SEED = 42

CUSTOMER_COUNT = 120
PRODUCT_COUNT = 500
ORDER_COUNT = 320

MIN_ORDER_ITEMS = 1
MAX_ORDER_ITEMS = 3

PAYMENT_COUNT = 320
SHIPMENT_COUNT = 290
RETURN_COUNT = 30

OUTPUT_FILE = Path(__file__).resolve().parent.parent / "sql" / "03_insert_raw_data.sql"

random.seed(RANDOM_SEED)

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

def random_date(start_date: date, end_date: date) -> date:
    """Return a random date between start_date and end_date."""

    days = (end_date - start_date).days

    return start_date + timedelta(
        days=random.randint(0, days)
    )


def random_datetime(start_date: date, end_date: date) -> datetime:
    """Return a random datetime between two dates."""

    selected_date = random_date(start_date, end_date)

    hour = random.randint(8, 21)
    minute = random.randint(0, 59)
    second = random.randint(0, 59)

    return datetime(
        selected_date.year,
        selected_date.month,
        selected_date.day,
        hour,
        minute,
        second,
    )


def money(value) -> Decimal:
    """Convert a value to two-decimal monetary value."""

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

    value = str(value).replace("'", "''")

    return f"'{value}'"


def sql_insert(table_name, columns, rows):
    """Generate INSERT statements for a table."""

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

def generate_customers():
    customers = []

    start_date = date(2022, 1, 1)
    end_date = date(2026, 8, 31)

    for customer_id in range(1, CUSTOMER_COUNT + 1):

        first_name = random.choice(FIRST_NAMES)
        last_name = random.choice(LAST_NAMES)

        customer_name = f"{first_name} {last_name}"

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
            ["Male", "Female", "Other"]
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

        updated_at = datetime.combine(
            signup_date,
            datetime.min.time(),
        ) + timedelta(
            days=random.randint(0, 365),
            hours=random.randint(0, 23),
        )

        ingested_at = updated_at + timedelta(
            hours=random.randint(1, 48)
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

def generate_products():
    products = []

    product_start_date = date(2022, 1, 1)
    product_end_date = date(2026, 8, 31)

    category_names = list(CATEGORIES.keys())

    for product_id in range(1, PRODUCT_COUNT + 1):

        category = random.choice(category_names)

        subcategory = random.choice(
            CATEGORIES[category]
        )

        brand = random.choice(BRANDS)

        product_name = (
            f"{brand} "
            f"{subcategory.replace(' ', '')} "
            f"Product {product_id}"
        )

        supplier_id = random.randint(1, 50)

        cost_price = money(
            random.uniform(200, 20000)
        )

        margin = random.uniform(0.10, 0.45)

        selling_price = money(
            cost_price * Decimal(
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
            ["Active", "Inactive", "Discontinued"]
        )

        launch_date = random_date(
            product_start_date,
            product_end_date,
        )

        updated_at = random_datetime(
            launch_date,
            product_end_date,
        )

        ingested_at = updated_at + timedelta(
            hours=random.randint(1, 48)
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

def generate_orders(customers):
    orders = []

    order_start_date = date(2026, 1, 1)
    order_end_date = date(2026, 8, 31)

    for order_id in range(1, ORDER_COUNT + 1):

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
            ["Paid", "Pending", "Failed"],
            weights=[80, 10, 10],
        )[0]

        shipping_method = random.choice(
            SHIPPING_METHODS
        )

        shipping_cost = money(
            random.uniform(40, 250)
        )

        discount_amount = money(
            random.uniform(0, 1000)
        )

        tax_amount = money(
            random.uniform(50, 2500)
        )

        sales_channel = random.choice(
            SALES_CHANNELS
        )

        updated_at = order_date + timedelta(
            hours=random.randint(1, 72)
        )

        ingested_at = updated_at + timedelta(
            hours=random.randint(1, 48)
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

def generate_order_items(orders, products):
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

        order_subtotal = Decimal("0.00")

        for product in selected_products:

            product_id = product[0]
            historical_price = product[7]

            quantity = random.randint(
                1,
                5,
            )

            discount_amount = money(
                random.uniform(0, 300)
            )

            tax_amount = money(
                random.uniform(0, 500)
            )

            line_total = money(
                historical_price * quantity
                - discount_amount
                + tax_amount
            )

            returned_quantity = 0

            updated_at = (
                order["updated_at"]
                + timedelta(
                    minutes=random.randint(1, 120)
                )
            )

            ingested_at = (
                updated_at
                + timedelta(
                    hours=random.randint(1, 24)
                )
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

        # Update order total based on item-level data.
        order["total_amount"] = money(
            order_subtotal
            + order["shipping_cost"]
        )

    order_items[20]["quantity"] = -1

    order_items[40]["line_total"] = money(
        order_items[40]["line_total"] + 500
    )

    totals = {}

    for item in order_items:

        order_id = item["order_id"]

        totals.setdefault(
            order_id,
            Decimal("0.00"),
        )

        totals[order_id] += item["line_total"]

    for order in orders:

        order["total_amount"] = money(
            totals[order["order_id"]]
            + order["shipping_cost"]
        )

    return order_items

def generate_payments(orders):
    payments = []

    payment_id = 1

    for order in orders:

        payment_status = order["payment_status"]

        if payment_status == "Failed":

            amount = money(
                order["total_amount"]
            )

        else:

            amount = money(
                order["total_amount"]
            )

        payment_date = (
            order["order_date"]
            + timedelta(
                hours=random.randint(1, 12)
            )
        )

        updated_at = payment_date + timedelta(
            hours=random.randint(1, 24)
        )

        ingested_at = updated_at + timedelta(
            hours=random.randint(1, 24)
        )

        transaction_reference = (
            f"TXN-{payment_id:06d}"
        )

        payments.append(
            (
                payment_id,
                order["order_id"],
                payment_date,
                random.choice(PAYMENT_METHODS),
                payment_status,
                amount,
                transaction_reference,
                updated_at,
                ingested_at,
            )
        )

        payment_id += 1

    return payments

def generate_shipments(orders):
    shipments = []

    shipment_id = 1

    eligible_orders = [
        order
        for order in orders
        if order["order_status"]
        not in ["Cancelled", "Pending"]
    ]

    selected_orders = random.sample(
        eligible_orders,
        min(
            SHIPMENT_COUNT,
            len(eligible_orders),
        ),
    )

    for order in selected_orders:

        shipped_at = (
            order["order_date"]
            + timedelta(
                days=random.randint(1, 3)
            )
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

        if shipment_status == "Delivered":

            delivered_at = (
                shipped_at
                + timedelta(
                    days=random.randint(1, 7)
                )
            )

        else:

            delivered_at = None

        city, state, _ = random.choice(
            LOCATIONS
        )

        updated_at = (
            delivered_at
            if delivered_at
            else shipped_at
        )

        updated_at = updated_at + timedelta(
            hours=random.randint(1, 24)
        )

        ingested_at = updated_at + timedelta(
            hours=random.randint(1, 24)
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

        return_date = (
            item["updated_at"]
            + timedelta(
                days=random.randint(2, 30)
            )
        )

        refund_amount = money(
            item["unit_price"]
            * return_quantity
        )

        return_status = random.choice(
            RETURN_STATUSES
        )

        updated_at = (
            return_date
            + timedelta(
                hours=random.randint(1, 48)
            )
        )

        ingested_at = (
            updated_at
            + timedelta(
                hours=random.randint(1, 24)
            )
        )

        returns.append(
            (
                return_id,
                item["order_item_id"],
                return_date,
                random.choice(RETURN_REASONS),
                return_quantity,
                refund_amount,
                return_status,
                updated_at,
                ingested_at,
            )
        )

        return_id += 1

    return returns

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

    # sql.append()

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

    sql.extend(
        sql_insert(
            "customers",
            customer_columns,
            customers,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "products",
            product_columns,
            products,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "orders",
            order_columns,
            order_rows,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "order_items",
            order_item_columns,
            order_item_rows,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "payments",
            payment_columns,
            payments,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "shipments",
            shipment_columns,
            shipments,
        )
    )

    # sql.append()

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

    sql.extend(
        sql_insert(
            "returns",
            return_columns,
            returns,
        )
    )

    # sql.append()

    return "\n".join(sql)

def main():

    print("=" * 60)
    print("E-COMMERCE RAW DATA GENERATOR")
    print("=" * 60)

    print("\nGenerating customers...")
    customers = generate_customers()

    print("Generating products...")
    products = generate_products()

    print("Generating orders...")
    orders = generate_orders(customers)

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

    sql = generate_sql(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    OUTPUT_FILE.write_text(
        sql,
        encoding="utf-8",
    )

    print("\n" + "=" * 60)
    print("DATA GENERATION COMPLETE")
    print("=" * 60)

    print(f"\nCustomers   : {len(customers)}")
    print(f"Products    : {len(products)}")
    print(f"Orders      : {len(orders)}")
    print(f"Order Items : {len(order_items)}")
    print(f"Payments    : {len(payments)}")
    print(f"Shipments   : {len(shipments)}")
    print(f"Returns     : {len(returns)}")

    print(f"\nSQL file:")
    print(OUTPUT_FILE)

    print("\nRandom seed:")
    print(RANDOM_SEED)

    print("\nThe generated SQL is ready to be loaded into PostgreSQL.")


if __name__ == "__main__":
    main()