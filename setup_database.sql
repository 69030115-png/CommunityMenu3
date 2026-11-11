-- Run ONCE in MySQL Workbench as root (or a database administrator).
-- Local classroom/demo defaults; matches config.ini.
-- Does not delete existing data. Tables/demo rows are created by the app
-- when the database is empty. Do not reimport the data export over existing data.
CREATE DATABASE IF NOT EXISTS community_menu
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'menu_user'@'localhost' IDENTIFIED BY 'your_password';
ALTER USER 'menu_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON community_menu.* TO 'menu_user'@'localhost';
