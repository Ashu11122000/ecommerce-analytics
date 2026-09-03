-- Mock Raw Data Ingestion

-- 1. Insert Customers
INSERT INTO raw.customers (customer_id, customer_name, email, city, signup_date)
VALUES
    (1, 'Aarav Sharma', 'aarav.sharma@gmail.com', 'Delhi', '2024-01-15'),
    (2, 'Priya Verma', 'priya.verma@gmail.com', 'Mumbai', '2024-02-10'),
    (3, 'Rahul Kumar', 'rahul.kumar@gmail.com', 'Bangalore', '2024-02-18'),
    (4, 'Sneha Patel', 'sneha.patel@gmail.com', 'Ahmedabad', '2024-03-05'),
    (5, 'Vikram Singh', 'vikram.singh@gmail.com', 'Jaipur', '2024-03-20'),
    (6, 'Ananya Gupta', 'ananya.gupta@gmail.com', 'Delhi', '2024-04-12'),
    (7, 'Rohan Mehta', 'rohan.mehta@gmail.com', 'Pune', '2024-04-25'),
    (8, 'Kavya Nair', 'kavya.nair@gmail.com', 'Kochi', '2024-05-10'),
    (9, 'Arjun Reddy', 'arjun.reddy@gmail.com', 'Hyderabad', '2024-05-22'),
    (10, 'Neha Joshi', 'neha.joshi@gmail.com', 'Mumbai', '2024-06-08'),
    (11, 'Aditya Malhotra', 'aditya.malhotra@gmail.com', 'Chandigarh', '2024-06-18'),
    (12, 'Ishita Roy', 'ishita.roy@gmail.com', 'Kolkata', '2024-07-03'),
    (13, 'Karan Shah', 'karan.shah@gmail.com', 'Surat', '2024-07-15'),
    (14, 'Meera Iyer', 'meera.iyer@gmail.com', 'Chennai', '2024-08-01'),
    (15, 'Siddharth Jain', 'siddharth.jain@gmail.com', 'Indore', '2024-08-20');

-- 2. Insert Products
INSERT INTO raw.products (product_id, product_name, category, price)
VALUES
    (1, 'Wireless Mouse', 'Electronics', 799.00),
    (2, 'Mechanical Keyboard', 'Electronics', 2499.00),
    (3, 'USB-C Charger', 'Electronics', 1299.00),
    (4, 'Laptop Stand', 'Accessories', 1599.00),
    (5, 'Bluetooth Headphones', 'Electronics', 2999.00),
    (6, 'Running Shoes', 'Footwear', 3499.00),
    (7, 'Cotton T-Shirt', 'Clothing', 699.00),
    (8, 'Denim Jeans', 'Clothing', 1999.00),
    (9, 'Backpack', 'Accessories', 1799.00),
    (10, 'Smart Watch', 'Electronics', 4999.00),
    (11, 'Water Bottle', 'Home & Lifestyle', 499.00),
    (12, 'Coffee Mug', 'Home & Lifestyle', 399.00),
    (13, 'Notebook', 'Stationery', 199.00),
    (14, 'Desk Lamp', 'Home & Lifestyle', 1499.00),
    (15, 'Phone Holder', 'Accessories', 599.00);

-- 3. Insert Orders
INSERT INTO raw.orders (order_id, customer_id, order_date, order_status)
VALUES
    (101, 1, '2024-09-01 10:15:00', 'Completed'),
    (102, 2, '2024-09-02 11:30:00', 'Completed'),
    (103, 3, '2024-09-03 14:20:00', 'Completed'),
    (104, 1, '2024-09-05 09:45:00', 'Completed'),
    (105, 4, '2024-09-06 16:10:00', 'Completed'),
    (106, 5, '2024-09-08 12:25:00', 'Completed'),
    (107, 6, '2024-09-10 18:05:00', 'Completed'),
    (108, 7, '2024-09-12 13:40:00', 'Completed'),
    (109, 8, '2024-09-15 10:50:00', 'Completed'),
    (110, 9, '2024-09-18 15:30:00', 'Completed'),
    (111, 10, '2024-09-21 11:15:00', 'Completed'),
    (112, 2, '2024-10-01 09:20:00', 'Completed'),
    (113, 11, '2024-10-03 14:45:00', 'Completed'),
    (114, 12, '2024-10-05 17:10:00', 'Completed'),
    (115, 3, '2024-10-08 10:30:00', 'Completed'),
    (116, 13, '2024-10-12 12:50:00', 'Completed'),
    (117, 14, '2024-10-15 16:20:00', 'Completed'),
    (118, 15, '2024-10-18 11:40:00', 'Completed'),
    (119, 4, '2024-10-22 13:15:00', 'Completed'),
    (120, 5, '2024-10-25 18:30:00', 'Completed'),
    (121, 6, '2024-11-02 09:35:00', 'Completed'),
    (122, 7, '2024-11-06 14:10:00', 'Completed'),
    (123, 8, '2024-11-10 10:25:00', 'Completed'),
    (124, 9, '2024-11-14 15:50:00', 'Completed'),
    (125, 10, '2024-11-18 12:05:00', 'Completed'),
    (126, 11, '2024-11-22 16:45:00', 'Completed'),
    (127, 12, '2024-12-01 11:10:00', 'Completed'),
    (128, 13, '2024-12-05 13:30:00', 'Completed'),
    (129, 14, '2024-12-10 17:25:00', 'Completed'),
    (130, 15, '2024-12-15 10:00:00', 'Completed');

-- 4. Insert Order Items
INSERT INTO raw.order_items (order_item_id, order_id, product_id, quantity, unit_price)
VALUES
    -- Order 101
    (1001, 101, 1, 2, 799.00),
    (1002, 101, 13, 3, 199.00),

    -- Order 102
    (1003, 102, 2, 1, 2499.00),
    (1004, 102, 4, 1, 1599.00),

    -- Order 103
    (1005, 103, 5, 1, 2999.00),
    (1006, 103, 3, 2, 1299.00),

    -- Order 104
    (1007, 104, 7, 3, 699.00),
    (1008, 104, 8, 1, 1999.00),

    -- Order 105
    (1009, 105, 6, 1, 3499.00),
    (1010, 105, 9, 1, 1799.00),

    -- Order 106
    (1011, 106, 10, 1, 4999.00),
    (1012, 106, 15, 2, 599.00),

    -- Order 107
    (1013, 107, 11, 2, 499.00),
    (1014, 107, 12, 3, 399.00),

    -- Order 108
    (1015, 108, 1, 1, 799.00),
    (1016, 108, 4, 1, 1599.00),

    -- Order 109
    (1017, 109, 5, 1, 2999.00),
    (1018, 109, 9, 2, 1799.00),

    -- Order 110
    (1019, 110, 6, 1, 3499.00),
    (1020, 110, 7, 2, 699.00),

    -- Order 111
    (1021, 111, 2, 1, 2499.00),
    (1022, 111, 3, 1, 1299.00),

    -- Order 112
    (1023, 112, 8, 1, 1999.00),
    (1024, 112, 13, 5, 199.00),

    -- Order 113
    (1025, 113, 10, 1, 4999.00),
    (1026, 113, 14, 1, 1499.00),

    -- Order 114
    (1027, 114, 12, 4, 399.00),
    (1028, 114, 11, 2, 499.00),

    -- Order 115
    (1029, 115, 1, 2, 799.00),
    (1030, 115, 15, 1, 599.00),

    -- Order 116
    (1031, 116, 5, 1, 2999.00),
    (1032, 116, 3, 1, 1299.00),

    -- Order 117
    (1033, 117, 6, 1, 3499.00),
    (1034, 117, 7, 2, 699.00),

    -- Order 118
    (1035, 118, 9, 1, 1799.00),
    (1036, 118, 4, 1, 1599.00),

    -- Order 119
    (1037, 119, 2, 1, 2499.00),
    (1038, 119, 8, 2, 1999.00),

    -- Order 120
    (1039, 120, 10, 1, 4999.00),
    (1040, 120, 1, 1, 799.00),

    -- Order 121
    (1041, 121, 14, 2, 1499.00),
    (1042, 121, 13, 3, 199.00),

    -- Order 122
    (1043, 122, 5, 1, 2999.00),
    (1044, 122, 15, 2, 599.00),

    -- Order 123
    (1045, 123, 6, 1, 3499.00),
    (1046, 123, 11, 3, 499.00),

    -- Order 124
    (1047, 124, 2, 1, 2499.00),
    (1048, 124, 9, 1, 1799.00),

    -- Order 125
    (1049, 125, 7, 4, 699.00),
    (1050, 125, 12, 2, 399.00),

    -- Order 126
    (1051, 126, 10, 1, 4999.00),
    (1052, 126, 4, 1, 1599.00),

    -- Order 127
    (1053, 127, 3, 2, 1299.00),
    (1054, 127, 1, 1, 799.00),

    -- Order 128
    (1055, 128, 8, 1, 1999.00),
    (1056, 128, 14, 1, 1499.00),

    -- Order 129
    (1057, 129, 5, 1, 2999.00),
    (1058, 129, 6, 1, 3499.00),

    -- Order 130
    (1059, 130, 9, 2, 1799.00),
    (1060, 130, 15, 1, 599.00);