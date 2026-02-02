-- Pahad Food Database Schema

-- Cities
CREATE TABLE cities (
  city_id SERIAL PRIMARY KEY,
  city_name VARCHAR(100) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customers
CREATE TABLE customers (
  customer_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) UNIQUE NOT NULL,
  address TEXT,
  city_id INT REFERENCES cities(city_id),
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chefs
CREATE TABLE chefs (
  chef_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) UNIQUE NOT NULL,
  address TEXT,
  city_id INT REFERENCES cities(city_id),
  password_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deliverers
CREATE TABLE deliverers (
  deliverer_id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) UNIQUE NOT NULL,
  city_id INT REFERENCES cities(city_id),
  is_available BOOLEAN DEFAULT true,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Menu
CREATE TABLE menu (
  item_id SERIAL PRIMARY KEY,
  item_name VARCHAR(200) NOT NULL,
  chef_id INT REFERENCES chefs(chef_id),
  price DECIMAL(10,2) NOT NULL,
  image_url TEXT,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders
CREATE TABLE orders (
  order_id SERIAL PRIMARY KEY,
  customer_id INT REFERENCES customers(customer_id),
  city_id INT REFERENCES cities(city_id),
  delivery_type VARCHAR(20) CHECK (delivery_type IN ('delivery', 'self_pickup')),
  delivery_person_id INT REFERENCES deliverers(deliverer_id),
  current_status VARCHAR(20) CHECK (current_status IN ('placed', 'accepted', 'prepared', 'picked_up', 'delivered', 'cancelled')),
  delivery_amount DECIMAL(10,2) DEFAULT 0,
  platform_fee DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items
CREATE TABLE order_items (
  order_item_id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(order_id),
  item_id INT REFERENCES menu(item_id),
  chef_id INT REFERENCES chefs(chef_id),
  quantity INT NOT NULL,
  price_at_order_time DECIMAL(10,2) NOT NULL,
  chef_amount DECIMAL(10,2) NOT NULL
);

-- Order Status History
CREATE TABLE order_status_history (
  id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(order_id),
  status VARCHAR(20) NOT NULL,
  changed_by VARCHAR(20) CHECK (changed_by IN ('customer', 'chef', 'delivery', 'system')),
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Payments
CREATE TABLE payments (
  payment_id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(order_id),
  payment_method VARCHAR(50),
  payment_status VARCHAR(20),
  amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  notification_id SERIAL PRIMARY KEY,
  user_type VARCHAR(20) CHECK (user_type IN ('customer', 'chef', 'delivery')),
  user_id INT NOT NULL,
  order_id INT REFERENCES orders(order_id),
  title VARCHAR(200),
  message TEXT,
  is_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(current_status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_chef ON order_items(chef_id);
CREATE INDEX idx_menu_chef ON menu(chef_id);

-- Enable RLS
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

-- RLS Policies (Allow all for simplicity - customize based on security needs)
CREATE POLICY "Allow all" ON cities FOR ALL USING (true);
CREATE POLICY "Allow all" ON customers FOR ALL USING (true);
CREATE POLICY "Allow all" ON chefs FOR ALL USING (true);
CREATE POLICY "Allow all" ON deliverers FOR ALL USING (true);
CREATE POLICY "Allow all" ON menu FOR ALL USING (true);
CREATE POLICY "Allow all" ON orders FOR ALL USING (true);
CREATE POLICY "Allow all" ON order_items FOR ALL USING (true);
CREATE POLICY "Allow all" ON order_status_history FOR ALL USING (true);
CREATE POLICY "Allow all" ON payments FOR ALL USING (true);
CREATE POLICY "Allow all" ON notifications FOR ALL USING (true);

-- Sample Data
INSERT INTO cities (city_name) VALUES ('Baddi'), ('Solan'), ('Shimla');

INSERT INTO chefs (name, phone, address, city_id, password_hash) VALUES 
('Chef Ramesh', '9876543210', 'Main Market, Baddi', 1, 'chef123'),
('Chef Priya', '9876543211', 'Mall Road, Solan', 2, 'chef123');

INSERT INTO deliverers (name, phone, city_id) VALUES 
('Rajesh Delivery', '9876543220', 1),
('Amit Delivery', '9876543221', 2);

INSERT INTO menu (item_name, chef_id, price, image_url) VALUES 
('Veg Momo', 1, 80, 'https://github.com/chinurxg/pahadfood/raw/main/food/momo.jpg'),
('Paneer Tikka', 1, 120, 'https://github.com/chinurxg/pahadfood/raw/main/food/momo.jpg'),
('Dal Makhani', 2, 150, 'https://github.com/chinurxg/pahadfood/raw/main/food/momo.jpg');