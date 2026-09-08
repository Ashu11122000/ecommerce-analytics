"""
Generate realistic mock e-commerce RAW data.

Output:
    sql/03_insert_raw_data.sql

Generated RAW tables:
    - customers
    - products
    - orders
    - order_items
    - payments
    - shipments
    - returns

Target record counts:
    - customers   = 120
    - products    = 500
    - orders      = 320
    - order_items = approximately 600
    - payments    = 320
    - shipments   = 290
    - returns     = 30

The generated data includes:
    - realistic Indian e-commerce data
    - valid primary/foreign-key relationships
    - historical order-item prices
    - business/event timestamps
    - updated_at timestamps
    - ingested_at timestamps
    - late-arriving records
    - updated records
    - NULL values
    - controlled data-quality issues
    - realistic order/payment/shipment/return states
    - reproducible data using a fixed random seed

Timestamp strategy:

    event/business timestamp
        =
        when the business event actually happened

    updated_at
        =
        when the source record was last updated

    ingested_at
        =
        when the record arrived in the RAW layer

Important:

    RAW intentionally contains a small number of controlled
    data-quality problems so that Bronze/Silver transformations
    can demonstrate validation and cleansing.

This script uses only Python standard-library modules.
"""

from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import random


# ============================================================
# CONFIGURATION
# ============================================================

RANDOM_SEED = 42

# Simulated current/source-system date.
DATA_AS_OF = datetime(
    2026,
    9,
    8,
    23,
    59,
    59,
)

CUSTOMER_COUNT = 120
PRODUCT_COUNT = 500
ORDER_COUNT = 320

# Approximately 600 order items.
#
# Distribution:
#   15% -> 1 item
#   70% -> 2 items
#   15% -> 3 items
#
# Expected average = 2.0 items/order.
#
# With 320 orders, expected order items ~= 640.
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
    "Riya",
    "Simran",
    "Aditi",
    "Nisha",
    "Manish",
    "Rajat",
    "Aman",
    "Sahil",
    "Varun",
    "Deepak",
    "Nitin",
    "Suresh",
    "Ankit",
    "Mohit",
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
    "Kapoor",
    "Malhotra",
    "Bansal",
    "Chopra",
    "Sethi",
    "Arora",
    "Mishra",
    "Pandey",
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
    ("Chandigarh", "Chandigarh", "160001"),
    ("Amritsar", "Punjab", "143001"),
    ("Ludhiana", "Punjab", "141001"),
    ("Bathinda", "Punjab", "151001"),
    ("Indore", "Madhya Pradesh", "452001"),
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
    "TechPro",
    "HomeCraft",
    "StyleHub",
    "Glow",
    "ReadMore",
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


PAYMENT_METHODS = [
    "UPI",
    "Credit Card",
    "Debit Card",
    "Net Banking",
    "Cash on Delivery",
    "Wallet",
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

def random_date(
    start_date: date,
    end_date: date,
) -> date:
    """Return a random date between two dates."""

    if start_date > end_date:
        raise ValueError(
            "start_date cannot be after end_date."
        )

    days = (
        end_date - start_date
    ).days

    return (
        start_date
        + timedelta(
            days=random.randint(
                0,
                days,
            )
        )
    )


def random_datetime(
    start_date: date,
    end_date: date,
) -> datetime:
    """
    Return a random datetime between two dates.

    Generated datetime never exceeds DATA_AS_OF.
    """

    if start_date > end_date:
        raise ValueError(
            "start_date cannot be after end_date."
        )

    selected_date = random_date(
        start_date,
        end_date,
    )

    generated_datetime = datetime(
        selected_date.year,
        selected_date.month,
        selected_date.day,
        random.randint(8, 21),
        random.randint(0, 59),
        random.randint(0, 59),
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
    """Add random hours without exceeding DATA_AS_OF."""

    if min_hours > max_hours:
        raise ValueError(
            "min_hours cannot be greater than max_hours."
        )

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
    """Add random days without exceeding DATA_AS_OF."""

    if min_days > max_days:
        raise ValueError(
            "min_days cannot be greater than max_days."
        )

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

    return Decimal(
        str(value)
    ).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )


def sql_string(value) -> str:
    """
    Convert Python values into SQL literals.

    None       -> NULL
    Decimal    -> numeric literal
    int/float  -> numeric literal
    date/time  -> quoted literal
    string     -> escaped quoted literal
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
    table_name: str,
    columns: list[str],
    rows: list[tuple],
) -> list[str]:
    """Generate one INSERT statement per row."""

    if not rows:
        return []

    statements = []

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


def choose_order_item_count() -> int:
    """
    Generate realistic order item counts.

    Distribution:
        15% -> 1 item
        70% -> 2 items
        15% -> 3 items

    Expected average = 2 items/order.
    """

    probability = random.random()

    if probability < 0.15:
        return 1

    if probability < 0.85:
        return 2

    return 3


# ============================================================
# CUSTOMERS
# ============================================================

def generate_customers():

    customers = []

    start_date = date(
        2022,
        1,
        1,
    )

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
            "@example.com"
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

        signup_datetime = datetime.combine(
            signup_date,
            datetime.min.time(),
        )

        max_update_datetime = min(
            signup_datetime
            + timedelta(days=365),
            DATA_AS_OF,
        )

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

        else:

            updated_at = signup_datetime

        ingested_at = add_hours_capped(
            updated_at,
            1,
            48,
        )

        # ----------------------------------------------------
        # Controlled NULL scenario.
        # ----------------------------------------------------

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
                "India",
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

        margin = Decimal(
            str(
                random.uniform(
                    0.10,
                    0.45,
                )
            )
        )

        selling_price = money(
            cost_price
            * (Decimal("1.00") + margin)
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
                5,      # Pending
                10,     # Confirmed
                10,     # Shipped
                55,     # Delivered
                8,      # Cancelled
                12,     # Returned
            ],
        )[0]

        # ----------------------------------------------------
        # Payment state is derived from order state.
        # ----------------------------------------------------

        if order_status == "Cancelled":

            payment_status = random.choices(
                [
                    "Failed",
                    "Refunded",
                    "Pending",
                ],
                weights=[
                    50,
                    30,
                    20,
                ],
            )[0]

        elif order_status == "Returned":

            payment_status = "Refunded"

        elif order_status == "Pending":

            payment_status = random.choices(
                [
                    "Pending",
                    "Failed",
                    "Paid",
                ],
                weights=[
                    50,
                    30,
                    20,
                ],
            )[0]

        else:

            payment_status = random.choices(
                [
                    "Paid",
                    "Pending",
                    "Failed",
                ],
                weights=[
                    85,
                    10,
                    5,
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
                "total_amount": Decimal("0.00"),
                "sales_channel": sales_channel,
                "currency": CURRENCY,
                "updated_at": updated_at,
                "ingested_at": ingested_at,
            }
        )

    # ========================================================
    # CONTROLLED LATE-ARRIVING RECORD
    # ========================================================

    late_order = orders[-1]

    # Business event happened much earlier.
    late_order["order_date"] = datetime(
        2026,
        8,
        1,
        10,
        0,
        0,
    )

    # Source record was updated much later.
    late_order["updated_at"] = datetime(
        2026,
        9,
        6,
        9,
        30,
        0,
    )

    # Warehouse received it even later.
    late_order["ingested_at"] = datetime(
        2026,
        9,
        7,
        8,
        15,
        0,
    )

    late_order["order_status"] = "Delivered"
    late_order["payment_status"] = "Paid"

    # ========================================================
    # CONTROLLED UPDATED-RECORD SCENARIO
    # ========================================================

    updated_order = orders[9]

    updated_order["order_status"] = "Delivered"
    updated_order["payment_status"] = "Paid"

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

        item_count = choose_order_item_count()

        # Only products already launched can be ordered.
        eligible_products = [
            product
            for product in products
            if product[11]
            <= order["order_date"].date()
        ]

        if len(eligible_products) < item_count:

            raise ValueError(
                f"Not enough eligible products for "
                f"order {order['order_id']}."
            )

        selected_products = random.sample(
            eligible_products,
            item_count,
        )

        order_subtotal = Decimal("0.00")

        for product in selected_products:

            product_id = product[0]

            current_selling_price = product[7]

            # ------------------------------------------------
            # Historical order price.
            #
            # The price actually paid can differ from the
            # current product selling price.
            # ------------------------------------------------

            historical_factor = Decimal(
                str(
                    random.uniform(
                        0.90,
                        1.10,
                    )
                )
            )

            historical_price = money(
                current_selling_price
                * historical_factor
            )

            quantity = random.randint(
                1,
                5,
            )

            discount_amount = money(
                historical_price
                * quantity
                * Decimal(
                    str(
                        random.uniform(
                            0.00,
                            0.15,
                        )
                    )
                )
            )

            taxable_amount = (
                historical_price
                * quantity
                - discount_amount
            )

            tax_rate = Decimal(
                str(
                    random.choice(
                        [
                            0.05,
                            0.12,
                            0.18,
                        ]
                    )
                )
            )

            tax_amount = money(
                taxable_amount
                * tax_rate
            )

            line_total = money(
                taxable_amount
                + tax_amount
            )

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
                    "returned_quantity": 0,
                    "updated_at": updated_at,
                    "ingested_at": ingested_at,
                }
            )

            order_subtotal += line_total

            order_item_id += 1

        order["total_amount"] = money(
            order_subtotal
            + order["shipping_cost"]
            - order["discount_amount"]
            + order["tax_amount"]
        )

        if order["total_amount"] < Decimal("0.00"):

            order["total_amount"] = Decimal(
                "0.00"
            )

    # ========================================================
    # CONTROLLED DATA-QUALITY ISSUE #1
    # ========================================================
    #
    # Negative quantity.
    #
    # RAW intentionally contains this invalid value.
    # ========================================================

    order_items[20]["quantity"] = -1

    # ========================================================
    # CONTROLLED DATA-QUALITY ISSUE #2
    # ========================================================
    #
    # Incorrect line total.
    # ========================================================

    order_items[40]["line_total"] = money(
        order_items[40]["line_total"]
        + 500
    )

    return order_items


# ============================================================
# PAYMENTS
# ============================================================

def generate_payments(orders):

    payments = []

    payment_id = 1

    for order in orders:

        payment_status = order[
            "payment_status"
        ]

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
        in [
            "Confirmed",
            "Shipped",
            "Delivered",
            "Returned",
        ]
    ]

    if len(eligible_orders) < SHIPMENT_COUNT:

        raise ValueError(
            "Not enough eligible orders to generate "
            f"{SHIPMENT_COUNT} shipments."
        )

    selected_orders = random.sample(
        eligible_orders,
        SHIPMENT_COUNT,
    )

    for order in selected_orders:

        # ----------------------------------------------------
        # Shipment state follows order state.
        # ----------------------------------------------------

        if order["order_status"] == "Confirmed":

            shipment_status = random.choice(
                [
                    "Processing",
                    "Shipped",
                    "In Transit",
                ]
            )

        elif order["order_status"] == "Shipped":

            shipment_status = random.choice(
                [
                    "Shipped",
                    "In Transit",
                    "Delayed",
                ]
            )

        elif order["order_status"] in [
            "Delivered",
            "Returned",
        ]:

            shipment_status = "Delivered"

        else:

            shipment_status = "Processing"

        # ----------------------------------------------------
        # Processing:
        # shipment has not physically shipped yet.
        # ----------------------------------------------------

        if shipment_status == "Processing":

            shipped_at = None
            delivered_at = None

            updated_base = order["order_date"]

        else:

            shipped_at = add_days_capped(
                order["order_date"],
                1,
                3,
            )

            if shipment_status == "Delivered":

                delivered_at = add_days_capped(
                    shipped_at,
                    1,
                    7,
                )

            else:

                delivered_at = None

            updated_base = (
                delivered_at
                if delivered_at is not None
                else shipped_at
            )

        city, state, _ = random.choice(
            LOCATIONS
        )

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

def generate_returns(
    order_items,
    orders,
):

    returns = []

    order_lookup = {
        order["order_id"]: order
        for order in orders
    }

    # Returns are normally possible only for completed/
    # delivered customer orders.
    eligible_items = [
        item
        for item in order_items
        if item["quantity"] > 0
        and order_lookup[
            item["order_id"]
        ]["order_status"]
        in [
            "Delivered",
            "Returned",
        ]
    ]

    if len(eligible_items) < RETURN_COUNT:

        raise ValueError(
            "Not enough eligible order items to generate "
            f"{RETURN_COUNT} returns."
        )

    selected_items = random.sample(
        eligible_items,
        RETURN_COUNT,
    )

    return_records = []

    return_id = 1

    for item in selected_items:

        return_quantity = random.randint(
            1,
            item["quantity"],
        )

        return_date = add_days_capped(
            item["updated_at"],
            2,
            30,
        )

        refund_amount = money(
            item["unit_price"]
            * return_quantity
        )

        return_status = random.choices(
            RETURN_STATUSES,
            weights=[
                15,     # Requested
                25,     # Approved
                50,     # Completed
                10,     # Rejected
            ],
        )[0]

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

        return_records.append(
            {
                "return_id": return_id,
                "order_item_id": item[
                    "order_item_id"
                ],
                "return_date": return_date,
                "return_reason": random.choice(
                    RETURN_REASONS
                ),
                "return_quantity": return_quantity,
                "refund_amount": refund_amount,
                "return_status": return_status,
                "updated_at": updated_at,
                "ingested_at": ingested_at,
            }
        )

        # Keep order_items.returned_quantity consistent
        # with the generated return.
        item["returned_quantity"] += (
            return_quantity
        )

        return_id += 1

    return return_records


# ============================================================
# CONTROLLED DATA-QUALITY SCENARIOS
# ============================================================

def apply_controlled_data_quality_issues(
    customers,
    products,
    order_items,
):
    """
    Apply intentional RAW-layer quality issues.

    These are deliberately introduced so that later dbt
    Bronze/Silver models can demonstrate cleansing and
    validation.

    Issues:
        1. NULL phone
        2. inconsistent category casing
        3. negative quantity
        4. incorrect line total
    """

    # --------------------------------------------------------
    # 1. NULL phone
    # --------------------------------------------------------

    customer_index = 16

    customer = customers[
        customer_index
    ]

    customers[
        customer_index
    ] = (
        customer[0],
        customer[1],
        customer[2],
        None,
        customer[4],
        customer[5],
        customer[6],
        customer[7],
        customer[8],
        customer[9],
        customer[10],
        customer[11],
        customer[12],
        customer[13],
        customer[14],
    )

    # --------------------------------------------------------
    # 2. Inconsistent category casing.
    #
    # Example:
    #
    #     Electronics
    #
    # becomes:
    #
    #     electronics
    #
    # Silver can standardize this later.
    # --------------------------------------------------------

    product_index = 25

    product = products[
        product_index
    ]

    products[
        product_index
    ] = (
        product[0],
        product[1],
        product[2].lower(),
        product[3],
        product[4],
        product[5],
        product[6],
        product[7],
        product[8],
        product[9],
        product[10],
        product[11],
        product[12],
        product[13],
    )

    # --------------------------------------------------------
    # 3. Negative quantity.
    # --------------------------------------------------------

    order_items[20]["quantity"] = -1

    # --------------------------------------------------------
    # 4. Incorrect line total.
    # --------------------------------------------------------

    order_items[40]["line_total"] = money(
        order_items[40]["line_total"]
        + 500
    )


# ============================================================
# BUSINESS RELATIONSHIP VALIDATION
# ============================================================

def validate_relationships(
    customers,
    products,
    orders,
    order_items,
    payments,
    shipments,
    returns,
):
    """
    Validate primary-key and foreign-key style relationships
    before generating SQL.
    """

    print("\nRelationship validation:")
    print("-" * 60)

    customer_ids = {
        customer[0]
        for customer in customers
    }

    product_ids = {
        product[0]
        for product in products
    }

    order_ids = {
        order["order_id"]
        for order in orders
    }

    order_item_ids = {
        item["order_item_id"]
        for item in order_items
    }

    violations = []

    # --------------------------------------------------------
    # Orders -> Customers
    # --------------------------------------------------------

    for order in orders:

        if order["customer_id"] not in customer_ids:

            violations.append(
                f"order {order['order_id']} "
                f"references missing customer "
                f"{order['customer_id']}"
            )

    # --------------------------------------------------------
    # Order Items -> Orders / Products
    # --------------------------------------------------------

    for item in order_items:

        if item["order_id"] not in order_ids:

            violations.append(
                f"order_item "
                f"{item['order_item_id']} "
                f"references missing order "
                f"{item['order_id']}"
            )

        if item["product_id"] not in product_ids:

            violations.append(
                f"order_item "
                f"{item['order_item_id']} "
                f"references missing product "
                f"{item['product_id']}"
            )

    # --------------------------------------------------------
    # Payments -> Orders
    # --------------------------------------------------------

    for payment in payments:

        if payment[1] not in order_ids:

            violations.append(
                f"payment {payment[0]} "
                f"references missing order "
                f"{payment[1]}"
            )

    # --------------------------------------------------------
    # Shipments -> Orders
    # --------------------------------------------------------

    for shipment in shipments:

        if shipment[1] not in order_ids:

            violations.append(
                f"shipment {shipment[0]} "
                f"references missing order "
                f"{shipment[1]}"
            )

    # --------------------------------------------------------
    # Returns -> Order Items
    # --------------------------------------------------------

    for return_record in returns:

        if (
            return_record["order_item_id"]
            not in order_item_ids
        ):

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"references missing order_item "
                f"{return_record['order_item_id']}"
            )

    if violations:

        print(
            f"FAILED: {len(violations)} "
            "relationship violations found."
        )

        for violation in violations[:20]:

            print(
                f"  - {violation}"
            )

        raise ValueError(
            "Relationship validation failed."
        )

    print(
        "All foreign-key style relationships are valid."
    )


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
    Validate timestamp rules.

    General rule:

        event
          <= updated_at
          <= ingested_at
          <= DATA_AS_OF

    Shipment Processing records may have:
        shipped_at = NULL
        delivered_at = NULL
    """

    print("\nTimestamp validation:")
    print("-" * 60)

    violations = []

    # --------------------------------------------------------
    # Customers
    # --------------------------------------------------------

    for customer in customers:

        signup_date = customer[12]
        updated_at = customer[13]
        ingested_at = customer[14]

        signup_datetime = datetime.combine(
            signup_date,
            datetime.min.time(),
        )

        if updated_at < signup_datetime:

            violations.append(
                f"customer {customer[0]} "
                f"updated_at < signup_date"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"customer {customer[0]} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"customer {customer[0]} "
                f"ingested_at > DATA_AS_OF"
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

        launch_date = product[11]
        updated_at = product[12]
        ingested_at = product[13]

        launch_datetime = datetime.combine(
            launch_date,
            datetime.min.time(),
        )

        if updated_at < launch_datetime:

            violations.append(
                f"product {product[0]} "
                f"updated_at < launch_date"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"product {product[0]} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"product {product[0]} "
                f"ingested_at > DATA_AS_OF"
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
                f"order {order['order_id']} "
                f"order_date > DATA_AS_OF"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"order {order['order_id']} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"order {order['order_id']} "
                f"ingested_at > DATA_AS_OF"
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
                f"{item['order_item_id']} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"order_item "
                f"{item['order_item_id']} "
                f"ingested_at > DATA_AS_OF"
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
                f"payment {payment[0]} "
                f"payment_date > DATA_AS_OF"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"payment {payment[0]} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"payment {payment[0]} "
                f"ingested_at > DATA_AS_OF"
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

        if (
            shipped_at is not None
            and shipped_at > DATA_AS_OF
        ):

            violations.append(
                f"shipment {shipment[0]} "
                f"shipped_at > DATA_AS_OF"
            )

        if (
            delivered_at is not None
            and delivered_at > DATA_AS_OF
        ):

            violations.append(
                f"shipment {shipment[0]} "
                f"delivered_at > DATA_AS_OF"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"shipment {shipment[0]} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"shipment {shipment[0]} "
                f"ingested_at > DATA_AS_OF"
            )

        if (
            shipped_at is not None
            and delivered_at is not None
            and delivered_at < shipped_at
        ):

            violations.append(
                f"shipment {shipment[0]} "
                f"delivered_at < shipped_at"
            )

        if (
            shipped_at is not None
            and updated_at < shipped_at
        ):

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

        return_date = return_record["return_date"]
        updated_at = return_record["updated_at"]
        ingested_at = return_record["ingested_at"]

        if return_date > DATA_AS_OF:

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"return_date > DATA_AS_OF"
            )

        if updated_at > DATA_AS_OF:

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"updated_at > DATA_AS_OF"
            )

        if ingested_at > DATA_AS_OF:

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"ingested_at > DATA_AS_OF"
            )

        if updated_at < return_date:

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"updated_at < return_date"
            )

        if ingested_at < updated_at:

            violations.append(
                f"return "
                f"{return_record['return_id']} "
                f"ingested_at < updated_at"
            )

    if violations:

        print(
            f"FAILED: {len(violations)} "
            "timestamp violations found."
        )

        for violation in violations[:20]:

            print(
                f"  - {violation}"
            )

        raise ValueError(
            "Timestamp validation failed."
        )

    print(
        "All timestamp validations passed."
    )


# ============================================================
# RECORD COUNT VALIDATION
# ============================================================

def validate_counts(
    customers,
    products,
    orders,
    order_items,
    payments,
    shipments,
    returns,
):
    """Validate generated record counts."""

    print("\nRecord-count validation:")
    print("-" * 60)

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
            "Every order must contain at least "
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
            "Expected shipments between 280 and 300."
        )

    if not (
        20
        <= len(returns)
        <= 40
    ):

        raise ValueError(
            "Expected returns between 20 and 40."
        )

    # One payment per order in this educational dataset.
    payment_order_ids = {
        payment[1]
        for payment in payments
    }

    order_ids = {
        order["order_id"]
        for order in orders
    }

    if payment_order_ids != order_ids:

        raise ValueError(
            "Payments do not contain exactly one "
            "payment record for every order."
        )

    print(
        f"customers    = {len(customers)}"
    )

    print(
        f"products     = {len(products)}"
    )

    print(
        f"orders       = {len(orders)}"
    )

    print(
        f"order_items  = {len(order_items)}"
    )

    print(
        f"items/order  = "
        f"{len(order_items) / len(orders):.2f}"
    )

    print(
        f"payments     = {len(payments)}"
    )

    print(
        f"shipments    = {len(shipments)}"
    )

    print(
        f"returns      = {len(returns)}"
    )

    print(
        "\nRecord-count validation passed."
    )


# ============================================================
# DATA QUALITY SUMMARY
# ============================================================

def print_data_quality_summary(
    customers,
    products,
    orders,
    order_items,
):
    """Print summary of intentional RAW data-quality issues."""

    print(
        "\nControlled RAW data-quality scenarios:"
    )

    print("-" * 60)

    null_phone_count = sum(
        1
        for customer in customers
        if customer[3] is None
    )

    negative_quantity_count = sum(
        1
        for item in order_items
        if item["quantity"] < 0
    )

    inconsistent_category_count = sum(
        1
        for product in products
        if product[2]
        and product[2] != product[2].title()
    )

    late_order_count = sum(
        1
        for order in orders
        if (
            order["ingested_at"]
            - order["order_date"]
        ).days >= 7
    )

    print(
        f"NULL customer phones    : "
        f"{null_phone_count}"
    )

    print(
        f"Negative quantities     : "
        f"{negative_quantity_count}"
    )

    print(
        f"Inconsistent categories : "
        f"{inconsistent_category_count}"
    )

    print(
        f"Late-arriving orders    : "
        f"{late_order_count}"
    )

    print(
        "Incorrect line totals   : 1"
    )


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
        f"-- Random seed: {RANDOM_SEED}\n"
        f"-- Data as of: {DATA_AS_OF}\n"
    )

    sql.append(
        "-- WARNING: This resets the RAW tables before loading.\n"
    )

    # --------------------------------------------------------
    # Reset RAW tables.
    #
    # CASCADE handles the foreign-key relationships.
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

    # ========================================================
    # CUSTOMERS
    # ========================================================

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

    sql.extend(
        customer_sql
    )

    # ========================================================
    # PRODUCTS
    # ========================================================

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

    sql.extend(
        product_sql
    )

    # ========================================================
    # ORDERS
    # ========================================================

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

    sql.extend(
        order_sql
    )

    # ========================================================
    # ORDER ITEMS
    # ========================================================

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

    sql.extend(
        order_item_sql
    )

    # ========================================================
    # PAYMENTS
    # ========================================================

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

    sql.extend(
        payment_sql
    )

    # ========================================================
    # SHIPMENTS
    # ========================================================

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

    sql.extend(
        shipment_sql
    )

    # ========================================================
    # RETURNS
    # ========================================================

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

    return_rows = [
        (
            record["return_id"],
            record["order_item_id"],
            record["return_date"],
            record["return_reason"],
            record["return_quantity"],
            record["refund_amount"],
            record["return_status"],
            record["updated_at"],
            record["ingested_at"],
        )
        for record in returns
    ]

    return_sql = sql_insert(
        "returns",
        return_columns,
        return_rows,
    )

    sql.extend(
        return_sql
    )

    # --------------------------------------------------------
    # SQL generation validation.
    # --------------------------------------------------------

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

    print(
        "\nSQL generation validation:"
    )

    print("-" * 60)

    for table_name in expected_counts:

        expected = expected_counts[
            table_name
        ]

        actual = actual_counts[
            table_name
        ]

        print(
            f"{table_name:<15}"
            f" expected={expected:<5}"
            f" generated={actual:<5}"
        )

        if expected != actual:

            raise ValueError(
                f"SQL generation failed for "
                f"{table_name}: expected "
                f"{expected} INSERT statements, "
                f"but generated {actual}."
            )

    print("-" * 60)

    print(
        "SQL generation validation passed."
    )

    return "\n".join(sql)


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 60)
    print(
        "E-COMMERCE RAW DATA GENERATOR"
    )
    print("=" * 60)

    print(
        f"\nData as of: {DATA_AS_OF}"
    )

    print(
        f"Random seed: {RANDOM_SEED}"
    )

    # ========================================================
    # GENERATE SOURCE DATASETS
    # ========================================================

    print(
        "\nGenerating customers..."
    )

    customers = generate_customers()

    print(
        "Generating products..."
    )

    products = generate_products()

    print(
        "Generating orders..."
    )

    orders = generate_orders()

    print(
        "Generating order items..."
    )

    order_items = generate_order_items(
        orders,
        products,
    )

    print(
        "Generating payments..."
    )

    payments = generate_payments(
        orders
    )

    print(
        "Generating shipments..."
    )

    shipments = generate_shipments(
        orders
    )

    print(
        "Generating returns..."
    )

    returns = generate_returns(
        order_items,
        orders,
    )

    # ========================================================
    # APPLY CONTROLLED DATA QUALITY ISSUES
    # ========================================================

    apply_controlled_data_quality_issues(
        customers,
        products,
        order_items,
    )

    # ========================================================
    # VALIDATE COUNTS
    # ========================================================

    validate_counts(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # ========================================================
    # VALIDATE RELATIONSHIPS
    # ========================================================

    validate_relationships(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # ========================================================
    # VALIDATE TIMESTAMPS
    # ========================================================

    validate_timestamps(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # ========================================================
    # PRINT DATA QUALITY SUMMARY
    # ========================================================

    print_data_quality_summary(
        customers,
        products,
        orders,
        order_items,
    )

    # ========================================================
    # GENERATE SQL
    # ========================================================

    sql = generate_sql(
        customers,
        products,
        orders,
        order_items,
        payments,
        shipments,
        returns,
    )

    # ========================================================
    # WRITE SQL FILE
    # ========================================================

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    OUTPUT_FILE.write_text(
        sql,
        encoding="utf-8",
    )

    # ========================================================
    # FINAL OUTPUT
    # ========================================================

    print(
        "\n" + "=" * 60
    )

    print(
        "DATA GENERATION COMPLETE"
    )

    print(
        "=" * 60
    )

    print(
        f"\nCustomers   : {len(customers)}"
    )

    print(
        f"Products    : {len(products)}"
    )

    print(
        f"Orders      : {len(orders)}"
    )

    print(
        f"Order Items : {len(order_items)}"
    )

    print(
        f"Payments    : {len(payments)}"
    )

    print(
        f"Shipments   : {len(shipments)}"
    )

    print(
        f"Returns     : {len(returns)}"
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
        "to be loaded into PostgreSQL."
    )


if __name__ == "__main__":
    main()