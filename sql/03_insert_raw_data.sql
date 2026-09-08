-- WARNING: This resets the RAW tables before loading
-- the generated dataset.

TRUNCATE TABLE raw.returns,
raw.shipments,
raw.payments,
raw.order_items,
raw.orders,
raw.products,
raw.customers
RESTART IDENTITY CASCADE;