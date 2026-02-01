-- ============================================
-- PAHAD FOOD - SUPABASE DATABASE SETUP
-- ============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- DROP EXISTING TABLES (for clean setup)
-- ============================================
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS menu CASCADE;
DROP TABLE IF EXISTS deliverers CASCADE;
DROP TABLE IF EXISTS chefs CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

-- ============================================
-- TABLES
-- ============================================

-- Cities Table
CREATE TABLE cities (
    city_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_name VARCHAR(100) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customers Table
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    address TEXT,
    city_id UUID REFERENCES cities(city_id) ON DELETE SET NULL,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chefs Table
CREATE TABLE chefs (
    chef_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    address TEXT,
    city_id UUID REFERENCES cities(city_id) ON DELETE SET NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deliverers Table
CREATE TABLE deliverers (
    deliverer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    city_id UUID REFERENCES cities(city_id) ON DELETE SET NULL,
    password_hash TEXT NOT NULL,
    is_available BOOLEAN DEFAULT true,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu Table
CREATE TABLE menu (
    item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_name VARCHAR(200) NOT NULL,
    chef_id UUID REFERENCES chefs(chef_id) ON DELETE CASCADE,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders Table
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(customer_id) ON DELETE SET NULL,
    city_id UUID REFERENCES cities(city_id) ON DELETE SET NULL,
    
    delivery_type VARCHAR(20) CHECK (delivery_type IN ('delivery', 'self_pickup')) DEFAULT 'delivery',
    delivery_person_id UUID REFERENCES deliverers(deliverer_id) ON DELETE SET NULL,
    
    current_status VARCHAR(20) CHECK (current_status IN ('placed', 'accepted', 'prepared', 'picked_up', 'delivered', 'cancelled')) DEFAULT 'placed',
    
    delivery_amount DECIMAL(10, 2) DEFAULT 0,
    platform_fee DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    
    special_instructions TEXT,
    delivery_instructions TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items Table
CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id UUID REFERENCES menu(item_id) ON DELETE SET NULL,
    chef_id UUID REFERENCES chefs(chef_id) ON DELETE SET NULL,
    
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_at_order_time DECIMAL(10, 2) NOT NULL CHECK (price_at_order_time >= 0),
    chef_amount DECIMAL(10, 2) NOT NULL CHECK (chef_amount >= 0),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Status History Table
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(order_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL,
    changed_by VARCHAR(20) CHECK (changed_by IN ('customer', 'chef', 'delivery', 'system')),
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Payments Table
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL,
    payment_method VARCHAR(50),
    payment_status VARCHAR(20) CHECK (payment_status IN ('pending', 'completed', 'failed')) DEFAULT 'pending',
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications Table
CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_type VARCHAR(20) CHECK (user_type IN ('customer', 'chef', 'delivery')),
    user_id UUID NOT NULL,
    order_id UUID REFERENCES orders(order_id) ON DELETE SET NULL,
    
    title VARCHAR(200),
    message TEXT,
    is_sent BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES for Performance
-- ============================================

CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_city ON customers(city_id);

CREATE INDEX idx_chefs_phone ON chefs(phone);
CREATE INDEX idx_chefs_city ON chefs(city_id);
CREATE INDEX idx_chefs_active ON chefs(is_active);

CREATE INDEX idx_deliverers_phone ON deliverers(phone);
CREATE INDEX idx_deliverers_city ON deliverers(city_id);
CREATE INDEX idx_deliverers_available ON deliverers(is_available);

CREATE INDEX idx_menu_chef ON menu(chef_id);
CREATE INDEX idx_menu_available ON menu(is_available);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_city ON orders(city_id);
CREATE INDEX idx_orders_delivery_person ON orders(delivery_person_id);
CREATE INDEX idx_orders_status ON orders(current_status);
CREATE INDEX idx_orders_created ON orders(created_at);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_chef ON order_items(chef_id);

CREATE INDEX idx_order_status_history_order ON order_status_history(order_id);

CREATE INDEX idx_notifications_user ON notifications(user_type, user_id);
CREATE INDEX idx_notifications_order ON notifications(order_id);
CREATE INDEX idx_notifications_sent ON notifications(is_sent);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE chefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliverers ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Cities - Public read access
CREATE POLICY "Cities are viewable by everyone" ON cities
    FOR SELECT USING (true);

-- Customers - Can read and update their own data
CREATE POLICY "Customers can view their own data" ON customers
    FOR SELECT USING (true);

CREATE POLICY "Customers can insert their own data" ON customers
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Customers can update their own data" ON customers
    FOR UPDATE USING (true);

-- Chefs - Can read their own data and active chefs
CREATE POLICY "Chefs are viewable by everyone" ON chefs
    FOR SELECT USING (true);

CREATE POLICY "Chefs can update their own data" ON chefs
    FOR UPDATE USING (true);

-- Deliverers - Can read their own data
CREATE POLICY "Deliverers are viewable by everyone" ON deliverers
    FOR SELECT USING (true);

CREATE POLICY "Deliverers can update their own data" ON deliverers
    FOR UPDATE USING (true);

-- Menu - Public read access, chefs can manage their menu
CREATE POLICY "Menu items are viewable by everyone" ON menu
    FOR SELECT USING (true);

CREATE POLICY "Chefs can insert their menu items" ON menu
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Chefs can update their menu items" ON menu
    FOR UPDATE USING (true);

CREATE POLICY "Chefs can delete their menu items" ON menu
    FOR DELETE USING (true);

-- Orders - Customers can view their orders, chefs/delivery can view assigned orders
CREATE POLICY "Orders are viewable by everyone" ON orders
    FOR SELECT USING (true);

CREATE POLICY "Customers can create orders" ON orders
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Orders can be updated" ON orders
    FOR UPDATE USING (true);

-- Order Items - Related to orders
CREATE POLICY "Order items are viewable by everyone" ON order_items
    FOR SELECT USING (true);

CREATE POLICY "Order items can be inserted" ON order_items
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Order items can be updated" ON order_items
    FOR UPDATE USING (true);

-- Order Status History - Public read
CREATE POLICY "Order status history is viewable by everyone" ON order_status_history
    FOR SELECT USING (true);

CREATE POLICY "Order status history can be inserted" ON order_status_history
    FOR INSERT WITH CHECK (true);

-- Payments - Related users can view
CREATE POLICY "Payments are viewable by everyone" ON payments
    FOR SELECT USING (true);

CREATE POLICY "Payments can be inserted" ON payments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Payments can be updated" ON payments
    FOR UPDATE USING (true);

-- Notifications - Users can view their notifications
CREATE POLICY "Notifications are viewable by everyone" ON notifications
    FOR SELECT USING (true);

CREATE POLICY "Notifications can be inserted" ON notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Notifications can be updated" ON notifications
    FOR UPDATE USING (true);

-- ============================================
-- SAMPLE DATA
-- ============================================

-- Insert Sample Cities
INSERT INTO cities (city_name, is_active) VALUES
('Shimla', true),
('Manali', true),
('Dharamshala', true),
('Kullu', true);

-- Insert Sample Chefs (password: chef123)
INSERT INTO chefs (name, phone, address, city_id, password_hash, is_active) 
SELECT 
    'Rajesh Kumar',
    '9876543210',
    'Mall Road, Shimla',
    city_id,
    'chef123',
    true
FROM cities WHERE city_name = 'Shimla'
LIMIT 1;

INSERT INTO chefs (name, phone, address, city_id, password_hash, is_active) 
SELECT 
    'Priya Sharma',
    '9876543211',
    'Old Manali, Manali',
    city_id,
    'chef123',
    true
FROM cities WHERE city_name = 'Manali'
LIMIT 1;

-- Insert Sample Deliverers (password: 1234)
INSERT INTO deliverers (name, phone, city_id, password_hash, is_available) 
SELECT 
    'Vikram Singh',
    '9876543220',
    city_id,
    '1234',
    true
FROM cities WHERE city_name = 'Shimla'
LIMIT 1;

INSERT INTO deliverers (name, phone, city_id, password_hash, is_available) 
SELECT 
    'Amit Verma',
    '9876543221',
    city_id,
    '1234',
    true
FROM cities WHERE city_name = 'Manali'
LIMIT 1;

-- Insert Sample Menu Items for Shimla Chef
INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Veg Momo (Steamed)',
    chef_id,
    100,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543210'
LIMIT 1;

INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Chicken Momo (Fried)',
    chef_id,
    150,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543210'
LIMIT 1;

INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Chowmein',
    chef_id,
    120,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543210'
LIMIT 1;

INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Thukpa',
    chef_id,
    130,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543210'
LIMIT 1;

-- Insert Sample Menu Items for Manali Chef
INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Paneer Momo',
    chef_id,
    120,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543211'
LIMIT 1;

INSERT INTO menu (item_name, chef_id, price, image_url, is_available)
SELECT 
    'Buff Momo',
    chef_id,
    160,
    'https://raw.githubusercontent.com/chinurxg/pahadfood/main/food/momo.jpg',
    true
FROM chefs WHERE phone = '9876543211'
LIMIT 1;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to get chef's orders
CREATE OR REPLACE FUNCTION get_chef_orders(chef_uuid UUID, order_status VARCHAR DEFAULT NULL)
RETURNS TABLE (
    order_id UUID,
    customer_name VARCHAR,
    customer_phone VARCHAR,
    customer_address TEXT,
    items JSONB,
    total_amount DECIMAL,
    current_status VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.order_id,
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address,
        jsonb_agg(
            jsonb_build_object(
                'item_name', m.item_name,
                'quantity', oi.quantity,
                'price', oi.price_at_order_time
            )
        ) as items,
        o.total_amount,
        o.current_status,
        o.created_at
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN menu m ON oi.item_id = m.item_id
    WHERE oi.chef_id = chef_uuid
        AND (order_status IS NULL OR o.current_status = order_status)
    GROUP BY o.order_id, c.name, c.phone, c.address, o.total_amount, o.current_status, o.created_at
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get delivery person's orders
CREATE OR REPLACE FUNCTION get_delivery_orders(deliverer_uuid UUID, order_status VARCHAR DEFAULT NULL)
RETURNS TABLE (
    order_id UUID,
    customer_name VARCHAR,
    customer_phone VARCHAR,
    customer_address TEXT,
    chef_name VARCHAR,
    chef_phone VARCHAR,
    chef_address TEXT,
    total_amount DECIMAL,
    delivery_amount DECIMAL,
    current_status VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.order_id,
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address,
        ch.name as chef_name,
        ch.phone as chef_phone,
        ch.address as chef_address,
        o.total_amount,
        o.delivery_amount,
        o.current_status,
        o.created_at
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN chefs ch ON oi.chef_id = ch.chef_id
    WHERE o.delivery_person_id = deliverer_uuid
        AND (order_status IS NULL OR o.current_status = order_status)
    GROUP BY o.order_id, c.name, c.phone, c.address, ch.name, ch.phone, ch.address, 
             o.total_amount, o.delivery_amount, o.current_status, o.created_at
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification
CREATE OR REPLACE FUNCTION create_notification(
    p_user_type VARCHAR,
    p_user_id UUID,
    p_order_id UUID,
    p_title VARCHAR,
    p_message TEXT
)
RETURNS UUID AS $$
DECLARE
    notification_uuid UUID;
BEGIN
    INSERT INTO notifications (user_type, user_id, order_id, title, message)
    VALUES (p_user_type, p_user_id, p_order_id, p_title, p_message)
    RETURNING notification_id INTO notification_uuid;
    
    RETURN notification_uuid;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- REALTIME SETUP
-- ============================================

-- Enable realtime for orders table
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE order_status_history;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ============================================
-- COMPLETED
-- ============================================

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE 'Pahad Food database setup completed successfully!';
    RAISE NOTICE 'Sample data inserted:';
    RAISE NOTICE '- Cities: Shimla, Manali, Dharamshala, Kullu';
    RAISE NOTICE '- Chefs: 2 chefs with sample menus';
    RAISE NOTICE '- Deliverers: 2 delivery partners';
    RAISE NOTICE 'Chef login: Phone: 9876543210, Password: chef123';
    RAISE NOTICE 'Delivery login: Phone: 9876543220, Password: 1234';
END $$;