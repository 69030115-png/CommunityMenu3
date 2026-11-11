-- MySQL Workbench Export for Community Menu Database
-- Generated from SQLite database
-- Compatible with MySQL 8.0+ and MariaDB 10.5+

-- ============================================================
-- DATABASE CREATION
-- ============================================================
CREATE DATABASE IF NOT EXISTS `community_menu`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `community_menu`;

-- ============================================================
-- TABLE: ingredients (วัตถุดิบ)
-- ============================================================
CREATE TABLE `ingredients` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(20) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `unit` VARCHAR(20) NOT NULL COMMENT 'หน่วยมาตรฐาน (กรัม / ฟอง / ชิ้น)',
    `min_stock` DECIMAL(10,2) DEFAULT 0.00 COMMENT 'สต็อกขั้นต่ำ',
    `shelf_days` INT UNSIGNED DEFAULT 7 COMMENT 'อายุการเก็บรักษา (วัน)',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_ingredients_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='วัตถุดิบ';

-- ============================================================
-- TABLE: farmers (เกษตรกร)
-- ============================================================
CREATE TABLE `farmers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(150) NOT NULL,
    `area` VARCHAR(100) DEFAULT NULL,
    `contact` VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='เกษตรกร';

-- ============================================================
-- TABLE: menus (เมนู)
-- ============================================================
CREATE TABLE `menus` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(20) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_menus_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='เมนู';

-- ============================================================
-- TABLE: recipe_items (สูตร: ปริมาณต่อ 1 จาน)
-- ============================================================
CREATE TABLE `recipe_items` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `menu_id` INT UNSIGNED NOT NULL,
    `ingredient_id` INT UNSIGNED NOT NULL,
    `qty_per_dish` DECIMAL(10,2) NOT NULL COMMENT 'ปริมาณต่อ 1 จาน (หน่วยมาตรฐาน)',
    PRIMARY KEY (`id`),
    KEY `idx_recipe_items_menu` (`menu_id`),
    KEY `idx_recipe_items_ingredient` (`ingredient_id`),
    CONSTRAINT `fk_recipe_items_menu` FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_recipe_items_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='สูตรอาหาร';

-- ============================================================
-- TABLE: lots (ล็อตวัตถุดิบ)
-- ============================================================
CREATE TABLE `lots` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ingredient_id` INT UNSIGNED NOT NULL,
    `received_date` DATE NOT NULL COMMENT 'วันที่รับเข้า',
    `use_by` DATE NOT NULL COMMENT 'วันหมดอายุ/ควรใช้ก่อน',
    `qty_left` DECIMAL(10,2) NOT NULL COMMENT 'จำนวนคงเหลือ (หน่วยมาตรฐาน)',
    `unit_cost` DECIMAL(10,4) NOT NULL COMMENT 'ราคาต่อหน่วยมาตรฐาน',
    `note` TEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_lots_ingredient` (`ingredient_id`),
    KEY `idx_lots_use_by` (`use_by`),
    CONSTRAINT `fk_lots_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ล็อตวัตถุดิบ';

-- ============================================================
-- TABLE: movements (ประวัติเคลื่อนไหว)
-- ============================================================
CREATE TABLE `movements` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ingredient_id` INT UNSIGNED NOT NULL,
    `lot_id` INT UNSIGNED DEFAULT NULL,
    `type` ENUM('IN','USE','WASTE','ADJUST') NOT NULL COMMENT 'ประเภท: IN=รับเข้า, USE=ใช้ไป, WASTE=เสีย, ADJUST=ปรับสต็อก',
    `qty` DECIMAL(10,2) NOT NULL,
    `unit_cost` DECIMAL(10,4) DEFAULT 0.0000,
    `created_at` DATETIME NOT NULL,
    `ref` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_movements_ingredient` (`ingredient_id`),
    KEY `idx_movements_lot` (`lot_id`),
    KEY `idx_movements_created_at` (`created_at`),
    CONSTRAINT `fk_movements_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_movements_lot` FOREIGN KEY (`lot_id`) REFERENCES `lots` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ประวัติเคลื่อนไหวสต็อก';

-- ============================================================
-- TABLE: produce (ผลผลิตพร้อมขายจากเกษตรกร)
-- ============================================================
CREATE TABLE `produce` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `farmer_id` INT UNSIGNED NOT NULL,
    `ingredient_id` INT UNSIGNED NOT NULL,
    `price` DECIMAL(10,2) NOT NULL COMMENT 'ราคาต่อหน่วยขาย',
    `sell_unit` VARCHAR(20) NOT NULL COMMENT 'หน่วยที่เกษตรกรขาย (กก. / กรัม / ฟอง / ชิ้น)',
    `qty_available` DECIMAL(10,2) NOT NULL COMMENT 'ปริมาณพร้อมขาย',
    `ready_date` DATE NOT NULL COMMENT 'วันที่พร้อมส่ง',
    `updated_at` DATETIME NOT NULL COMMENT 'อัปเดตล่าสุด',
    PRIMARY KEY (`id`),
    KEY `idx_produce_farmer` (`farmer_id`),
    KEY `idx_produce_ingredient` (`ingredient_id`),
    KEY `idx_produce_ready_date` (`ready_date`),
    CONSTRAINT `fk_produce_farmer` FOREIGN KEY (`farmer_id`) REFERENCES `farmers` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_produce_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ผลผลิตพร้อมขาย';

-- ============================================================
-- TABLE: menu_plans (แผนเมนู)
-- ============================================================
CREATE TABLE `menu_plans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plan_date` DATE NOT NULL COMMENT 'วันที่วางแผน',
    `budget` DECIMAL(12,2) DEFAULT 0.00 COMMENT 'งบประมาณ',
    `status` ENUM('DRAFT','CONFIRMED','USED') NOT NULL DEFAULT 'DRAFT' COMMENT 'สถานะ: DRAFT=草稿, CONFIRMED=ยืนยัน, USED=ใช้แล้ว',
    `created_at` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_menu_plans_date` (`plan_date`),
    KEY `idx_menu_plans_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='แผนเมนู';

-- ============================================================
-- TABLE: plan_items (รายการในแผนเมนู)
-- ============================================================
CREATE TABLE `plan_items` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plan_id` INT UNSIGNED NOT NULL,
    `menu_id` INT UNSIGNED NOT NULL,
    `dishes` INT UNSIGNED NOT NULL COMMENT 'จำนวนจาน',
    PRIMARY KEY (`id`),
    KEY `idx_plan_items_plan` (`plan_id`),
    KEY `idx_plan_items_menu` (`menu_id`),
    CONSTRAINT `fk_plan_items_plan` FOREIGN KEY (`plan_id`) REFERENCES `menu_plans` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_plan_items_menu` FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='รายการในแผนเมนู';

-- ============================================================
-- TABLE: purchase_orders (คำสั่งซื้อ)
-- ============================================================
CREATE TABLE `purchase_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `farmer_id` INT UNSIGNED NOT NULL,
    `plan_id` INT UNSIGNED DEFAULT NULL,
    `created_at` DATETIME NOT NULL,
    `status` ENUM('PENDING','RECEIVED','CANCELLED') NOT NULL DEFAULT 'PENDING' COMMENT 'สถานะ: PENDING=รอรับ, RECEIVED=รับแล้ว, CANCELLED=ยกเลิก',
    `received_at` DATETIME DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_purchase_orders_farmer` (`farmer_id`),
    KEY `idx_purchase_orders_plan` (`plan_id`),
    KEY `idx_purchase_orders_status` (`status`),
    CONSTRAINT `fk_purchase_orders_farmer` FOREIGN KEY (`farmer_id`) REFERENCES `farmers` (`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_purchase_orders_plan` FOREIGN KEY (`plan_id`) REFERENCES `menu_plans` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='คำสั่งซื้อ';

-- ============================================================
-- TABLE: po_items (รายการในคำสั่งซื้อ)
-- ============================================================
CREATE TABLE `po_items` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `po_id` INT UNSIGNED NOT NULL,
    `ingredient_id` INT UNSIGNED NOT NULL,
    `qty` DECIMAL(10,2) NOT NULL COMMENT 'จำนวน (หน่วยมาตรฐาน)',
    `unit_price` DECIMAL(10,4) NOT NULL COMMENT 'ราคาต่อหน่วยมาตรฐาน',
    PRIMARY KEY (`id`),
    KEY `idx_po_items_po` (`po_id`),
    KEY `idx_po_items_ingredient` (`ingredient_id`),
    CONSTRAINT `fk_po_items_po` FOREIGN KEY (`po_id`) REFERENCES `purchase_orders` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_po_items_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredients` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='รายการในคำสั่งซื้อ';

-- ============================================================
-- DATA INSERTION
-- ============================================================

-- Disable foreign key checks for bulk insert
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- ingredients (20 rows)
-- ------------------------------------------------------------
INSERT INTO `ingredients` (`id`, `code`, `name`, `unit`, `min_stock`, `shelf_days`) VALUES
(1, 'I01', 'ฟักทอง', 'กรัม', 1000.00, 10),
(2, 'I02', 'ไข่ไก่', 'ฟอง', 30.00, 14),
(3, 'I03', 'กระเทียม', 'กรัม', 200.00, 30),
(4, 'I04', 'น้ำมันพืช', 'กรัม', 500.00, 180),
(5, 'I05', 'ซอสหอยนางรม', 'กรัม', 300.00, 180),
(6, 'I06', 'ผักบุ้ง', 'กรัม', 500.00, 3),
(7, 'I07', 'หมูสับ', 'กรัม', 500.00, 3),
(8, 'I08', 'อกไก่', 'กรัม', 500.00, 3),
(9, 'I09', 'ข้าวสาร', 'กรัม', 5000.00, 180),
(10, 'I10', 'ใบกะเพรา', 'กรัม', 100.00, 3),
(11, 'I11', 'พริกขี้หนู', 'กรัม', 100.00, 7),
(12, 'I12', 'คะน้า', 'กรัม', 500.00, 4),
(13, 'I13', 'มะเขือเทศ', 'กรัม', 300.00, 7),
(14, 'I14', 'หอมหัวใหญ่', 'กรัม', 300.00, 20),
(15, 'I15', 'เต้าหู้ไข่', 'ชิ้น', 10.00, 7),
(16, 'I16', 'ถั่วฝักยาว', 'กรัม', 300.00, 5),
(17, 'I17', 'ตำลึง', 'กรัม', 200.00, 3),
(18, 'I18', 'น้ำปลา', 'กรัม', 300.00, 365),
(19, 'I19', 'น้ำตาลทราย', 'กรัม', 300.00, 365),
(20, 'I20', 'แตงกวา', 'กรัม', 300.00, 5);

-- ------------------------------------------------------------
-- farmers (5 rows)
-- ------------------------------------------------------------
INSERT INTO `farmers` (`id`, `name`, `area`, `contact`) VALUES
(1, 'กลุ่มเกษตรกรบ้านหนองบัว (จำลอง)', 'ต.หนองบัว', '081-000-0001'),
(2, 'ฟาร์มไข่ลุงชัย (จำลอง)', 'ต.ท่าช้าง', '081-000-0002'),
(3, 'สวนผักป้าแดง (จำลอง)', 'ต.บ้านใหม่', '081-000-0003'),
(4, 'วิสาหกิจชุมชนผักปลอดภัย (จำลอง)', 'ต.โนนสูง', '081-000-0004'),
(5, 'ฟาร์มหมูพี่เอก (จำลอง)', 'ต.หนองบัว', '081-000-0005');

-- ------------------------------------------------------------
-- menus (10 rows)
-- ------------------------------------------------------------
INSERT INTO `menus` (`id`, `code`, `name`) VALUES
(1, 'M01', 'ฟักทองผัดไข่'),
(2, 'M02', 'ผัดผักบุ้งไฟแดง'),
(3, 'M03', 'ข้าวกะเพราหมูสับ'),
(4, 'M04', 'ไข่เจียวหมูสับ'),
(5, 'M05', 'ผัดคะน้าหมูสับ'),
(6, 'M06', 'ไก่ผัดมะเขือเทศ'),
(7, 'M07', 'แกงจืดเต้าหู้หมูสับ'),
(8, 'M08', 'ผัดถั่วฝักยาวหมูสับ'),
(9, 'M09', 'ไข่ผัดมะเขือเทศ'),
(10, 'M10', 'แกงจืดฟักทองหมูสับ');

-- ------------------------------------------------------------
-- recipe_items (48 rows)
-- ------------------------------------------------------------
INSERT INTO `recipe_items` (`id`, `menu_id`, `ingredient_id`, `qty_per_dish`) VALUES
(1, 1, 1, 100.00),
(2, 1, 2, 1.00),
(3, 1, 3, 5.00),
(4, 1, 4, 10.00),
(5, 1, 5, 10.00),
(6, 2, 6, 150.00),
(7, 2, 3, 5.00),
(8, 2, 11, 3.00),
(9, 2, 4, 10.00),
(10, 2, 5, 15.00),
(11, 3, 7, 100.00),
(12, 3, 10, 10.00),
(13, 3, 11, 5.00),
(14, 3, 3, 5.00),
(15, 3, 9, 120.00),
(16, 3, 4, 10.00),
(17, 3, 18, 10.00),
(18, 4, 2, 2.00),
(19, 4, 7, 40.00),
(20, 4, 4, 30.00),
(21, 4, 18, 5.00),
(22, 5, 12, 150.00),
(23, 5, 7, 60.00),
(24, 5, 3, 5.00),
(25, 5, 5, 15.00),
(26, 5, 4, 10.00),
(27, 6, 8, 100.00),
(28, 6, 13, 80.00),
(29, 6, 14, 40.00),
(30, 6, 4, 10.00),
(31, 6, 19, 5.00),
(32, 7, 15, 1.00),
(33, 7, 7, 50.00),
(34, 7, 17, 30.00),
(35, 7, 18, 10.00),
(36, 8, 16, 120.00),
(37, 8, 7, 50.00),
(38, 8, 3, 5.00),
(39, 8, 18, 10.00),
(40, 8, 4, 10.00),
(41, 9, 2, 2.00),
(42, 9, 13, 100.00),
(43, 9, 14, 30.00),
(44, 9, 4, 10.00),
(45, 9, 19, 5.00),
(46, 10, 1, 120.00),
(47, 10, 7, 50.00),
(48, 10, 18, 10.00);

-- ------------------------------------------------------------
-- lots (19 rows)
-- ------------------------------------------------------------
INSERT INTO `lots` (`id`, `ingredient_id`, `received_date`, `use_by`, `qty_left`, `unit_cost`, `note`) VALUES
(1, 1, '2026-10-18', '2026-10-26', 2000.00, 0.0300, 'ข้อมูลจำลอง'),
(2, 2, '2026-10-21', '2026-11-03', 20.00, 5.0000, 'ข้อมูลจำลอง'),
(3, 3, '2026-10-14', '2026-11-13', 1000.00, 0.0800, 'ข้อมูลจำลอง'),
(4, 4, '2026-10-04', '2027-03-23', 3000.00, 0.0500, 'ข้อมูลจำลอง'),
(5, 5, '2026-10-04', '2027-03-23', 2000.00, 0.0900, 'ข้อมูลจำลอง'),
(6, 6, '2026-10-23', '2026-10-25', 600.00, 0.0300, 'ข้อมูลจำลอง'),
(7, 7, '2026-10-23', '2026-10-26', 1500.00, 0.1400, 'ข้อมูลจำลอง'),
(8, 8, '2026-10-23', '2026-10-26', 400.00, 0.1100, 'ข้อมูลจำลอง'),
(9, 9, '2026-10-09', '2027-03-23', 10000.00, 0.0300, 'ข้อมูลจำลอง'),
(10, 10, '2026-10-23', '2026-10-26', 150.00, 0.0600, 'ข้อมูลจำลอง'),
(11, 11, '2026-10-22', '2026-10-29', 200.00, 0.1000, 'ข้อมูลจำลอง'),
(12, 12, '2026-10-22', '2026-10-26', 300.00, 0.0400, 'ข้อมูลจำลอง'),
(13, 13, '2026-10-22', '2026-10-29', 800.00, 0.0400, 'ข้อมูลจำลอง'),
(14, 14, '2026-10-19', '2026-11-08', 1000.00, 0.0400, 'ข้อมูลจำลอง'),
(15, 15, '2026-10-22', '2026-10-29', 8.00, 10.0000, 'ข้อมูลจำลอง'),
(16, 16, '2026-10-23', '2026-10-28', 500.00, 0.0400, 'ข้อมูลจำลอง'),
(17, 18, '2026-09-24', '2027-08-20', 1500.00, 0.0500, 'ข้อมูลจำลอง'),
(18, 19, '2026-09-24', '2027-08-20', 2000.00, 0.0300, 'ข้อมูลจำลอง'),
(19, 20, '2026-10-23', '2026-10-28', 200.00, 0.0300, 'ข้อมูลจำลอง');

-- ------------------------------------------------------------
-- movements (19 rows)
-- ------------------------------------------------------------
INSERT INTO `movements` (`id`, `ingredient_id`, `lot_id`, `type`, `qty`, `unit_cost`, `created_at`, `ref`, `reason`) VALUES
(1, 1, 1, 'IN', 2000.00, 0.0300, '2026-10-18 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(2, 2, 2, 'IN', 20.00, 5.0000, '2026-10-21 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(3, 3, 3, 'IN', 1000.00, 0.0800, '2026-10-14 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(4, 4, 4, 'IN', 3000.00, 0.0500, '2026-10-04 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(5, 5, 5, 'IN', 2000.00, 0.0900, '2026-10-04 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(6, 6, 6, 'IN', 600.00, 0.0300, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(7, 7, 7, 'IN', 1500.00, 0.1400, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(8, 8, 8, 'IN', 400.00, 0.1100, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(9, 9, 9, 'IN', 10000.00, 0.0300, '2026-10-09 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(10, 10, 10, 'IN', 150.00, 0.0600, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(11, 11, 11, 'IN', 200.00, 0.1000, '2026-10-22 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(12, 12, 12, 'IN', 300.00, 0.0400, '2026-10-22 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(13, 13, 13, 'IN', 800.00, 0.0400, '2026-10-22 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(14, 14, 14, 'IN', 1000.00, 0.0400, '2026-10-19 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(15, 15, 15, 'IN', 8.00, 10.0000, '2026-10-22 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(16, 16, 16, 'IN', 500.00, 0.0400, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(17, 18, 17, 'IN', 1500.00, 0.0500, '2026-09-24 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(18, 19, 18, 'IN', 2000.00, 0.0300, '2026-09-24 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง'),
(19, 20, 19, 'IN', 200.00, 0.0300, '2026-10-23 08:00:00', 'ยอดยกมา', 'ข้อมูลจำลอง');

-- ------------------------------------------------------------
-- produce (12 rows)
-- ------------------------------------------------------------
INSERT INTO `produce` (`id`, `farmer_id`, `ingredient_id`, `price`, `sell_unit`, `qty_available`, `ready_date`, `updated_at`) VALUES
(1, 1, 1, 30.00, 'กก.', 50.00, '2026-10-24', '2026-10-24 17:45:17'),
(2, 3, 1, 35.00, 'กก.', 20.00, '2026-10-25', '2026-10-24 17:45:17'),
(3, 2, 2, 5.00, 'ฟอง', 300.00, '2026-10-24', '2026-10-24 17:45:17'),
(4, 4, 2, 5.50, 'ฟอง', 200.00, '2026-10-24', '2026-10-24 17:45:17'),
(5, 3, 6, 30.00, 'กก.', 15.00, '2026-10-24', '2026-10-24 17:45:17'),
(6, 3, 12, 40.00, 'กก.', 10.00, '2026-10-24', '2026-10-24 17:45:17'),
(7, 4, 16, 40.00, 'กก.', 10.00, '2026-10-25', '2026-10-24 17:45:17'),
(8, 4, 17, 50.00, 'กก.', 5.00, '2026-10-24', '2026-10-24 17:45:17'),
(9, 4, 13, 40.00, 'กก.', 15.00, '2026-10-24', '2026-10-24 17:45:17'),
(10, 1, 20, 25.00, 'กก.', 20.00, '2026-10-24', '2026-10-24 17:45:17'),
(11, 5, 7, 140.00, 'กก.', 30.00, '2026-10-24', '2026-10-24 17:45:17'),
(12, 1, 10, 60.00, 'กก.', 3.00, '2026-10-24', '2026-10-24 17:45:17');

-- ------------------------------------------------------------
-- menu_plans (0 rows - empty table)
-- ------------------------------------------------------------
-- No data for menu_plans

-- ------------------------------------------------------------
-- plan_items (0 rows - empty table)
-- ------------------------------------------------------------
-- No data for plan_items

-- ------------------------------------------------------------
-- purchase_orders (3 rows)
-- ------------------------------------------------------------
INSERT INTO `purchase_orders` (`id`, `farmer_id`, `plan_id`, `created_at`, `status`, `received_at`) VALUES
(1, 2, NULL, '2026-10-17 09:00:00', 'RECEIVED', '2026-10-17 15:00:00'),
(2, 3, NULL, '2026-10-19 09:00:00', 'RECEIVED', '2026-10-19 15:00:00'),
(3, 5, NULL, '2026-10-21 09:00:00', 'RECEIVED', '2026-10-21 15:00:00');

-- ------------------------------------------------------------
-- po_items (3 rows)
-- ------------------------------------------------------------
INSERT INTO `po_items` (`id`, `po_id`, `ingredient_id`, `qty`, `unit_price`) VALUES
(1, 1, 2, 60.00, 5.0000),
(2, 2, 6, 2000.00, 0.0300),
(3, 3, 7, 3000.00, 0.1400);

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- VIEWS (Optional - for reporting)
-- ============================================================

-- View: Current stock per ingredient
CREATE OR REPLACE VIEW `v_current_stock` AS
SELECT
    i.`id` AS `ingredient_id`,
    i.`code`,
    i.`name`,
    i.`unit`,
    i.`min_stock`,
    COALESCE(SUM(l.`qty_left`), 0) AS `total_qty`,
    CASE
        WHEN COALESCE(SUM(l.`qty_left`), 0) <= i.`min_stock` THEN 'LOW'
        WHEN COALESCE(SUM(l.`qty_left`), 0) <= i.`min_stock` * 1.5 THEN 'WARNING'
        ELSE 'OK'
    END AS `stock_status`
FROM `ingredients` i
LEFT JOIN `lots` l ON l.`ingredient_id` = i.`id` AND l.`qty_left` > 0
GROUP BY i.`id`, i.`code`, i.`name`, i.`unit`, i.`min_stock`;

-- View: Expiring lots (within 3 days)
CREATE OR REPLACE VIEW `v_expiring_lots` AS
SELECT
    l.`id` AS `lot_id`,
    i.`code`,
    i.`name` AS `ingredient_name`,
    i.`unit`,
    l.`received_date`,
    l.`use_by`,
    l.`qty_left`,
    l.`unit_cost`,
    DATEDIFF(l.`use_by`, CURDATE()) AS `days_remaining`
FROM `lots` l
JOIN `ingredients` i ON i.`id` = l.`ingredient_id`
WHERE l.`qty_left` > 0
  AND l.`use_by` <= DATE_ADD(CURDATE(), INTERVAL 3 DAY)
ORDER BY l.`use_by` ASC;

-- View: Recipe cost per dish
CREATE OR REPLACE VIEW `v_recipe_cost` AS
SELECT
    m.`id` AS `menu_id`,
    m.`code` AS `menu_code`,
    m.`name` AS `menu_name`,
    COALESCE(SUM(ri.`qty_per_dish` * l.`unit_cost`), 0) AS `estimated_cost_per_dish`
FROM `menus` m
JOIN `recipe_items` ri ON ri.`menu_id` = m.`id`
JOIN `ingredients` ing ON ing.`id` = ri.`ingredient_id`
LEFT JOIN (
    SELECT `ingredient_id`, AVG(`unit_cost`) AS `unit_cost`
    FROM `lots`
    WHERE `qty_left` > 0
    GROUP BY `ingredient_id`
) l ON l.`ingredient_id` = ing.`id`
GROUP BY m.`id`, m.`code`, m.`name`;

-- ============================================================
-- STORED PROCEDURES (Optional)
-- ============================================================

DELIMITER //

-- Procedure: Get low stock ingredients
CREATE PROCEDURE `sp_get_low_stock`()
BEGIN
    SELECT * FROM `v_current_stock` WHERE `stock_status` IN ('LOW', 'WARNING') ORDER BY `stock_status` DESC, `total_qty` ASC;
END //

-- Procedure: Get expiring lots
CREATE PROCEDURE `sp_get_expiring_lots`(IN p_days INT)
BEGIN
    SELECT * FROM `v_expiring_lots` WHERE `days_remaining` <= p_days ORDER BY `days_remaining` ASC;
END //

-- Procedure: Record stock movement
CREATE PROCEDURE `sp_record_movement`(
    IN p_ingredient_id INT UNSIGNED,
    IN p_lot_id INT UNSIGNED,
    IN p_type ENUM('IN','USE','WASTE','ADJUST'),
    IN p_qty DECIMAL(10,2),
    IN p_unit_cost DECIMAL(10,4),
    IN p_ref VARCHAR(100),
    IN p_reason TEXT
)
BEGIN
    INSERT INTO `movements` (`ingredient_id`, `lot_id`, `type`, `qty`, `unit_cost`, `created_at`, `ref`, `reason`)
    VALUES (p_ingredient_id, p_lot_id, p_type, p_qty, p_unit_cost, NOW(), p_ref, p_reason);

    -- Update lot qty_left for IN/USE/WASTE
    IF p_type IN ('IN', 'USE', 'WASTE') AND p_lot_id IS NOT NULL THEN
        UPDATE `lots`
        SET `qty_left` = `qty_left` + CASE WHEN p_type = 'IN' THEN p_qty ELSE -p_qty END
        WHERE `id` = p_lot_id;
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGERS (Optional)
-- ============================================================

DELIMITER //

-- Stock is updated by logic.py in the same transaction as the movement log.
-- Remove the incompatible trigger from earlier exports.
DROP TRIGGER IF EXISTS `trg_movement_after_insert` //

DELIMITER ;

-- ============================================================
-- INDEXES FOR PERFORMANCE (Additional)
-- ============================================================
-- Composite index for common queries
CREATE INDEX `idx_movements_ingredient_date` ON `movements` (`ingredient_id`, `created_at`);
CREATE INDEX `idx_lots_ingredient_qty` ON `lots` (`ingredient_id`, `qty_left`);
CREATE INDEX `idx_produce_ingredient_ready` ON `produce` (`ingredient_id`, `ready_date`);

-- ============================================================
-- END OF SCRIPT
-- ============================================================