-- ============================================================
-- RAW SCHEMA AND OLTP-STYLE SOURCE TABLE CREATION
-- ============================================================
--
-- This script creates the simulated source/RAW layer for the
-- E-Commerce Analytics Engineering project.
--
-- RAW tables represent data arriving from an operational
-- e-commerce source system.
--
-- Tables:
--     1. raw.customers
--     2. raw.products
--     3. raw.orders
--     4. raw.order_items
--     5. raw.payments
--     6. raw.shipments
--     7. raw.returns
--
-- Important:
--
-- RAW is intentionally close to the source-system structure.
-- Business transformations, standardization, cleansing and
-- analytics logic will be handled later by dbt Bronze/Silver/Gold
-- models.
--
-- Timestamp concepts:
--
--     business/event date
--         = when the business event happened
--
--     updated_at
--         = when the source record was last updated
--
--     ingested_at
--         = when the record arrived in the RAW layer
--
-- ============================================================


-- ============================================================
-- 1. CREATE RAW SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;


-- ============================================================
-- 2. CUSTOMERS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.customers (

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

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP

);


-- ============================================================
-- 3. PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.products (

    product_id INTEGER PRIMARY KEY,

    product_name VARCHAR(150) NOT NULL,

    category VARCHAR(100) NOT NULL,

    subcategory VARCHAR(100),

    brand VARCHAR(100),

    supplier_id INTEGER,

    cost_price NUMERIC(12, 2),

    selling_price NUMERIC(12, 2),

    stock_quantity INTEGER,

    reorder_level INTEGER,

    product_status VARCHAR(30),

    launch_date DATE,

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP

);


-- ============================================================
-- 4. ORDERS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.orders (

    order_id INTEGER PRIMARY KEY,

    customer_id INTEGER NOT NULL,

    order_date TIMESTAMP NOT NULL,

    order_status VARCHAR(50) NOT NULL,

    payment_status VARCHAR(50),

    shipping_method VARCHAR(50),

    shipping_cost NUMERIC(12, 2),

    discount_amount NUMERIC(12, 2),

    tax_amount NUMERIC(12, 2),

    total_amount NUMERIC(14, 2),

    sales_channel VARCHAR(50),

    currency VARCHAR(10),

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_orders_customer

        FOREIGN KEY (customer_id)

        REFERENCES raw.customers(customer_id)

);


-- ============================================================
-- 5. ORDER ITEMS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.order_items (

    order_item_id INTEGER PRIMARY KEY,

    order_id INTEGER NOT NULL,

    product_id INTEGER NOT NULL,

    quantity INTEGER NOT NULL,

    unit_price NUMERIC(12, 2) NOT NULL,

    discount_amount NUMERIC(12, 2),

    tax_amount NUMERIC(12, 2),

    line_total NUMERIC(14, 2),

    returned_quantity INTEGER,

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_items_order

        FOREIGN KEY (order_id)

        REFERENCES raw.orders(order_id),

    CONSTRAINT fk_order_items_product

        FOREIGN KEY (product_id)

        REFERENCES raw.products(product_id)

);


-- ============================================================
-- 6. PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.payments (

    payment_id INTEGER PRIMARY KEY,

    order_id INTEGER NOT NULL,

    payment_date TIMESTAMP NOT NULL,

    payment_method VARCHAR(50) NOT NULL,

    payment_status VARCHAR(50) NOT NULL,

    amount NUMERIC(14, 2) NOT NULL,

    transaction_reference VARCHAR(100),

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payments_order

        FOREIGN KEY (order_id)

        REFERENCES raw.orders(order_id)

);


-- ============================================================
-- 7. SHIPMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.shipments (

    shipment_id INTEGER PRIMARY KEY,

    order_id INTEGER NOT NULL,

    shipping_method VARCHAR(50) NOT NULL,

    shipment_status VARCHAR(50) NOT NULL,

    shipped_at TIMESTAMP,

    delivered_at TIMESTAMP,

    delivery_city VARCHAR(100),

    delivery_state VARCHAR(100),

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_shipments_order

        FOREIGN KEY (order_id)

        REFERENCES raw.orders(order_id)

);


-- ============================================================
-- 8. RETURNS
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.returns (

    return_id INTEGER PRIMARY KEY,

    order_item_id INTEGER NOT NULL,

    return_date TIMESTAMP NOT NULL,

    return_reason VARCHAR(100) NOT NULL,

    return_quantity INTEGER NOT NULL,

    refund_amount NUMERIC(14, 2) NOT NULL,

    return_status VARCHAR(50) NOT NULL,

    updated_at TIMESTAMP,

    ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_returns_order_item

        FOREIGN KEY (order_item_id)

        REFERENCES raw.order_items(order_item_id)

);


-- ============================================================
-- END OF RAW TABLE CREATION
-- ============================================================