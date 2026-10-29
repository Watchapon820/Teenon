-- สร้างฐานข้อมูล Teenon: mysql -u root -p < schema.sql
CREATE DATABASE IF NOT EXISTS teenon_db CHARACTER SET utf8mb4;
USE teenon_db;

CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(30) DEFAULT '',
  avatar_url VARCHAR(255) NULL,           -- รูปโปรไฟล์ (/uploads/avatars/xxx.jpg)
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user','admin') NOT NULL DEFAULT 'user'
);

CREATE TABLE IF NOT EXISTS hotels (
  hotel_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  location VARCHAR(200) DEFAULT '',
  description TEXT,
  rating DECIMAL(2,1) DEFAULT 0.0,
  check_in_time TIME DEFAULT '14:00:00',
  check_out_time TIME DEFAULT '12:00:00',
  has_pool TINYINT(1) DEFAULT 1,
  has_breakfast TINYINT(1) DEFAULT 1,
  has_wifi TINYINT(1) DEFAULT 1,
  image_url VARCHAR(255) NULL,
  cancellation_policy VARCHAR(255) NULL,
  free_cancel_days INT NOT NULL DEFAULT 3
);

CREATE TABLE IF NOT EXISTS rooms (
  room_id INT AUTO_INCREMENT PRIMARY KEY,
  hotel_id INT NOT NULL,
  room_type VARCHAR(100) NOT NULL,
  price_per_night DECIMAL(10,2) NOT NULL,
  image_url VARCHAR(255) NULL,
  quantity INT NOT NULL DEFAULT 5,        -- จำนวนห้องที่มี (ใช้ตรวจห้องว่าง)
  max_guests INT NULL,
  bed_type VARCHAR(50) NULL,
  size_sqm INT NULL,
  FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS hotel_tags (
  id INT AUTO_INCREMENT PRIMARY KEY,
  hotel_id INT NOT NULL,
  tag_name VARCHAR(50) NOT NULL,
  FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bookings (
  booking_id INT AUTO_INCREMENT PRIMARY KEY,
  booking_code VARCHAR(20) NOT NULL UNIQUE,
  user_id INT NOT NULL,
  hotel_id INT NOT NULL,
  room_id INT NOT NULL,
  guest_name VARCHAR(100),
  guest_email VARCHAR(150),
  guest_phone VARCHAR(30),
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  num_rooms INT DEFAULT 1,
  num_guests INT DEFAULT 1,
  special_request TEXT,
  total_amount DECIMAL(10,2) NOT NULL,
  status ENUM('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  payment_method VARCHAR(30) NULL,
  slip_file VARCHAR(255) NULL,
  paid_at DATETIME NULL,
  deal_id INT NULL,                          -- ดีลที่ใช้ตอนจอง (ถ้ามี)
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0,  -- จำนวนเงินที่ลดจากดีล
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id),
  FOREIGN KEY (room_id) REFERENCES rooms(room_id)
);

-- ดีล/โปรโมชัน: ส่วนลด % ของโรงแรมในช่วงวันที่ที่กำหนด (ใช้กับทุกประเภทห้อง) แอดมินตั้งค่าในแท็บ "ดีล"
CREATE TABLE IF NOT EXISTS deals (
  deal_id INT AUTO_INCREMENT PRIMARY KEY,
  hotel_id INT NOT NULL,
  title VARCHAR(100) NOT NULL,
  description VARCHAR(255) NULL,
  discount_percent TINYINT UNSIGNED NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_deals_hotel (hotel_id),
  FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE
);

-- บันทึกการชำระเงิน 1 รายการต่อ 1 การจอง (ส่งสลิป = pending, แอดมินยืนยัน = paid, ถูกยกเลิก = failed)
CREATE TABLE IF NOT EXISTS payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NOT NULL,
  payment_method ENUM('QR Payment','Credit / Debit Card','Bank Transfer') NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  slip_url VARCHAR(255) DEFAULT NULL,
  status ENUM('pending','paid','failed') DEFAULT 'paid',
  paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY booking_id (booking_id),
  FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cancellations (
  cancellation_id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NOT NULL,
  reason VARCHAR(100) NOT NULL,
  additional_details TEXT,
  cancelled_at DATETIME NOT NULL,
  FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

CREATE TABLE IF NOT EXISTS hotel_images (
  id INT AUTO_INCREMENT PRIMARY KEY,
  hotel_id INT NOT NULL,
  image_url VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reviews (
  review_id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NOT NULL UNIQUE,
  user_id INT NOT NULL,
  hotel_id INT NOT NULL,
  rating TINYINT NOT NULL,
  comment TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(150) NOT NULL,
  body VARCHAR(500) NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- รหัสยืนยันสำหรับลืมรหัสผ่าน (เก็บแบบ hash, ใช้ได้ครั้งเดียว)
CREATE TABLE IF NOT EXISTS password_resets (
  email VARCHAR(150) NOT NULL PRIMARY KEY,
  code_hash VARCHAR(100) NOT NULL,
  expires_at DATETIME NOT NULL,
  attempts INT NOT NULL DEFAULT 0
);

-- แชทลูกค้า ↔ แอดมิน (1 ลูกค้า = 1 ห้องสนทนา; read_at = เวลาที่อีกฝั่งอ่านแล้ว)
CREATE TABLE IF NOT EXISTS support_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  sender_role ENUM('user','admin') NOT NULL,
  sender_id INT NOT NULL,
  body VARCHAR(1000) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME NULL,
  INDEX idx_chat_thread (user_id, id),
  INDEX idx_chat_unread (user_id, sender_role, read_at)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS saved_hotels (
  user_id INT NOT NULL,
  hotel_id INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, hotel_id)
);

-- หมายเหตุ: เซิร์ฟเวอร์ปรับตารางที่ขาดให้อัตโนมัติตอนเริ่มทำงาน (ฐานข้อมูลเก่าใช้ต่อได้) ไฟล์นี้ไว้ตั้งค่าเครื่องใหม่
-- สร้างแอดมินคนแรก: npm run seed (รหัสผ่านสุ่มจะอยู่ในไฟล์ ADMIN_PASSWORD.txt)

-- ตั้งผู้ใช้เป็นแอดมิน: สมัครผ่านแอปก่อน แล้วรัน
-- UPDATE users SET role='admin' WHERE email='you@example.com';
