-- RAW Schema and OLTP-Style Source Table Creation

-- 1. Create RAW Schema

CREATE SCHEMA raw;

-- 2. Create Customers Table
CREATE TABLE raw.customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    gender VARCHAR(20),
    date_of_birth DATE,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(10),
    customer_segment VARCHAR(30),
    customer_status VARCHAR(30),
    signup_date DATE NOT NULL,
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create Products Table
CREATE TABLE raw.products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    supplier_id INTEGER,
    cost_price NUMERIC(10, 2),
    selling_price NUMERIC(10, 2),
    stock_quantity INTEGER,
    reorder_level INTEGER,
    product_status VARCHAR(30),
    launch_date DATE,
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create Orders Table
CREATE TABLE raw.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP NOT NULL,
    order_status VARCHAR(50) NOT NULL,
    payment_status VARCHAR(50),
    shipping_method VARCHAR(50),
    shipping_cost NUMERIC(10, 2),
    discount_amount NUMERIC(10, 2),
    tax_amount NUMERIC(10, 2),
    total_amount NUMERIC(12, 2),
    sales_channel VARCHAR(50),
    currency VARCHAR(10),
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES raw.customers(customer_id)

);

-- 5. Create Order Items Table
CREATE TABLE raw.order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    discount_amount NUMERIC(10, 2),
    tax_amount NUMERIC(10, 2),
    line_total NUMERIC(12, 2),
    returned_quantity INTEGER,
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES raw.products(product_id)

);

-- 6. Create Payments Table
CREATE TABLE raw.payments (
    payment_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    payment_date TIMESTAMP NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_status VARCHAR(50) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    transaction_reference VARCHAR(100),
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id)

);

-- 7. Create Shipments Table
CREATE TABLE raw.shipments (
    shipment_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    shipping_method VARCHAR(50) NOT NULL,
    shipment_status VARCHAR(50) NOT NULL,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    delivery_city VARCHAR(100),
    delivery_state VARCHAR(100),
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_shipments_order
        FOREIGN KEY (order_id)
        REFERENCES raw.orders(order_id)

);

-- 8. Create Returns Table
CREATE TABLE raw.returns (
    return_id INTEGER PRIMARY KEY,
    order_item_id INTEGER NOT NULL,
    return_date TIMESTAMP NOT NULL,
    return_reason VARCHAR(100) NOT NULL,
    return_quantity INTEGER NOT NULL,
    refund_amount NUMERIC(12, 2) NOT NULL,
    return_status VARCHAR(50) NOT NULL,
    updated_at TIMESTAMP,
    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_returns_order_item
        FOREIGN KEY (order_item_id)
        REFERENCES raw.order_items(order_item_id)

);
