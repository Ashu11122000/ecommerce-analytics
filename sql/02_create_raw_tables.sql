-- Raw Schema and OLTP-Style Table Creation

-- 1. Create Raw Schema
CREATE SCHEMA raw;

-- 2. Create Customers Table
CREATE TABLE raw.customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    city VARCHAR(100),
    signup_date DATE NOT NULL
);

-- 3. Create Products Table
CREATE TABLE raw.products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

-- 4. Create Orders Table
CREATE TABLE raw.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP NOT NULL,
    order_status VARCHAR(50) NOT NULL,

    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES raw.customers(customer_id)
);

-- 5. Create Order Items Table
CREATE TABLE raw.order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,

    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES raw.orders(order_id),

    CONSTRAINT fk_order_items_productFOREIGN KEY (product_id) REFERENCES raw.products(product_id)
);