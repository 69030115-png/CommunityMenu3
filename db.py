# db.py
# จัดการฐานข้อมูล MySQL: สร้างตาราง + ใส่ข้อมูลจำลองสำหรับเดโม

import os
import sys
import mysql.connector
from mysql.connector import errorcode
from datetime import date, datetime, timedelta
from mysql_compat import Connection
from configparser import ConfigParser
from pathlib import Path

# ---------- Config ----------
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "menu_user"),
    "password": os.getenv("DB_PASSWORD", "your_password"),
    "database": os.getenv("DB_NAME", "community_menu"),
    "charset": "utf8mb4",
    "collation": "utf8mb4_unicode_ci",
    "autocommit": False,
    "use_pure": True,  # ใช้ pure python driver กันปัญหา C extension บนบางเครื่อง
}

# config.ini is optional; environment variables take precedence.
_config = ConfigParser(interpolation=None)
_config.read(Path(__file__).with_name("config.ini"), encoding="utf-8-sig")
if _config.has_section("mysql"):
    for _key, _env in (("host", "DB_HOST"), ("port", "DB_PORT"),
                       ("user", "DB_USER"), ("password", "DB_PASSWORD"),
                       ("database", "DB_NAME")):
        if _env not in os.environ and _config.has_option("mysql", _key):
            DB_CONFIG[_key] = _config.get("mysql", _key)
DB_CONFIG["port"] = int(DB_CONFIG["port"])
DB_CONFIG["connection_timeout"] = 10

# ---------- Connection ----------
def get_conn():
    """MySQL connection supporting execute(), rows and with/commit/rollback."""
    return Connection(mysql.connector.connect(**DB_CONFIG))


def get_cursor(conn):
    """คืน cursor ที่เข้าถึง column ผ่าน dict ได้ (cursor(dictionary=True))"""
    return conn.cursor(dictionary=True)


# ---------- Helpers ----------
def today_str():
    return date.today().isoformat()


def now_str():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ---------- Schema ----------
DDL_STATEMENTS = [
    # วัตถุดิบ
    """CREATE TABLE IF NOT EXISTS ingredients (
        id INT AUTO_INCREMENT PRIMARY KEY,
        code VARCHAR(20) UNIQUE NOT NULL,
        name VARCHAR(100) NOT NULL,
        unit VARCHAR(20) NOT NULL,
        min_stock DECIMAL(10,2) DEFAULT 0,
        shelf_days INT DEFAULT 7
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # ล็อตวัตถุดิบ
    """CREATE TABLE IF NOT EXISTS lots (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ingredient_id INT NOT NULL,
        received_date DATE NOT NULL,
        use_by DATE NOT NULL,
        qty_left DECIMAL(10,2) NOT NULL,
        unit_cost DECIMAL(10,4) NOT NULL,
        note TEXT,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # ประวัติเคลื่อนไหว
    """CREATE TABLE IF NOT EXISTS movements (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ingredient_id INT NOT NULL,
        lot_id INT,
        type ENUM('IN','USE','WASTE','ADJUST') NOT NULL,
        qty DECIMAL(10,2) NOT NULL,
        unit_cost DECIMAL(10,4) DEFAULT 0,
        created_at DATETIME NOT NULL,
        ref VARCHAR(50),
        reason TEXT,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE RESTRICT,
        FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # เมนู
    """CREATE TABLE IF NOT EXISTS menus (
        id INT AUTO_INCREMENT PRIMARY KEY,
        code VARCHAR(20) UNIQUE NOT NULL,
        name VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # สูตร
    """CREATE TABLE IF NOT EXISTS recipe_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        menu_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        qty_per_dish DECIMAL(10,2) NOT NULL,
        FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE RESTRICT,
        UNIQUE KEY uniq_menu_ingredient (menu_id, ingredient_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # เกษตรกร
    """CREATE TABLE IF NOT EXISTS farmers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        area VARCHAR(100),
        contact VARCHAR(50)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # ผลผลิตพร้อมขาย
    """CREATE TABLE IF NOT EXISTS produce (
        id INT AUTO_INCREMENT PRIMARY KEY,
        farmer_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        sell_unit VARCHAR(20) NOT NULL,
        qty_available DECIMAL(10,2) NOT NULL,
        ready_date DATE NOT NULL,
        updated_at DATETIME NOT NULL,
        FOREIGN KEY (farmer_id) REFERENCES farmers(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # แผนเมนู
    """CREATE TABLE IF NOT EXISTS menu_plans (
        id INT AUTO_INCREMENT PRIMARY KEY,
        plan_date DATE NOT NULL,
        budget DECIMAL(10,2) DEFAULT 0,
        status ENUM('DRAFT','CONFIRMED','USED') NOT NULL DEFAULT 'DRAFT',
        created_at DATETIME NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    """CREATE TABLE IF NOT EXISTS plan_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        plan_id INT NOT NULL,
        menu_id INT NOT NULL,
        dishes INT NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES menu_plans(id) ON DELETE CASCADE,
        FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    # คำสั่งซื้อ
    """CREATE TABLE IF NOT EXISTS purchase_orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        farmer_id INT NOT NULL,
        plan_id INT,
        created_at DATETIME NOT NULL,
        status ENUM('PENDING','RECEIVED','CANCELLED') NOT NULL DEFAULT 'PENDING',
        received_at DATETIME,
        FOREIGN KEY (farmer_id) REFERENCES farmers(id) ON DELETE RESTRICT,
        FOREIGN KEY (plan_id) REFERENCES menu_plans(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",

    """CREATE TABLE IF NOT EXISTS po_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        po_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        qty DECIMAL(10,2) NOT NULL,
        unit_price DECIMAL(10,4) NOT NULL,
        FOREIGN KEY (po_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""",
]


def create_tables():
    with get_conn() as conn:
        cur = get_cursor(conn)
        for ddl in DDL_STATEMENTS:
            cur.execute(ddl)
        cur.close()


def is_empty():
    with get_conn() as conn:
        cur = get_cursor(conn)
        cur.execute("SELECT COUNT(*) AS cnt FROM ingredients")
        row = cur.fetchone()
        cur.close()
        return row["cnt"] == 0


def seed_demo_data():
    """ใส่ข้อมูลจำลอง (ไม่ใช่ข้อมูลจริงของร้าน) วัตถุดิบ 20 / สูตร 10 / เกษตรกร 5"""
    with get_conn() as conn:
        cur = get_cursor(conn)
        t = date.today()

        def d(days):
            return (t + timedelta(days=days)).isoformat()

        # วัตถุดิบ
        ingredients = [
            ("I01", "ฟักทอง", "กรัม", 1000, 10),
            ("I02", "ไข่ไก่", "ฟอง", 30, 14),
            ("I03", "กระเทียม", "กรัม", 200, 30),
            ("I04", "น้ำมันพืช", "กรัม", 500, 180),
            ("I05", "ซอสหอยนางรม", "กรัม", 300, 180),
            ("I06", "ผักบุ้ง", "กรัม", 500, 3),
            ("I07", "หมูสับ", "กรัม", 500, 3),
            ("I08", "อกไก่", "กรัม", 500, 3),
            ("I09", "ข้าวสาร", "กรัม", 5000, 180),
            ("I10", "ใบกะเพรา", "กรัม", 100, 3),
            ("I11", "พริกขี้หนู", "กรัม", 100, 7),
            ("I12", "คะน้า", "กรัม", 500, 4),
            ("I13", "มะเขือเทศ", "กรัม", 300, 7),
            ("I14", "หอมหัวใหญ่", "กรัม", 300, 20),
            ("I15", "เต้าหู้ไข่", "ชิ้น", 10, 7),
            ("I16", "ถั่วฝักยาว", "กรัม", 300, 5),
            ("I17", "ตำลึง", "กรัม", 200, 3),
            ("I18", "น้ำปลา", "กรัม", 300, 365),
            ("I19", "น้ำตาลทราย", "กรัม", 300, 365),
            ("I20", "แตงกวา", "กรัม", 300, 5),
        ]
        cur.executemany(
            "INSERT INTO ingredients(code,name,unit,min_stock,shelf_days) VALUES (%s,%s,%s,%s,%s)",
            ingredients,
        )
        # map name -> id
        cur.execute("SELECT id, name FROM ingredients")
        ing = {row["name"]: row["id"] for row in cur.fetchall()}

        # ล็อตเริ่มต้น
        lots = [
            ("ฟักทอง", -6, 2, 2000, 0.03),
            ("ไข่ไก่", -3, 10, 20, 5),
            ("กระเทียม", -10, 20, 1000, 0.08),
            ("น้ำมันพืช", -20, 150, 3000, 0.05),
            ("ซอสหอยนางรม", -20, 150, 2000, 0.09),
            ("ผักบุ้ง", -1, 1, 600, 0.03),
            ("หมูสับ", -1, 2, 1500, 0.14),
            ("อกไก่", -1, 2, 400, 0.11),
            ("ข้าวสาร", -15, 150, 10000, 0.03),
            ("ใบกะเพรา", -1, 2, 150, 0.06),
            ("พริกขี้หนู", -2, 5, 200, 0.1),
            ("คะน้า", -2, 2, 300, 0.04),
            ("มะเขือเทศ", -2, 5, 800, 0.04),
            ("หอมหัวใหญ่", -5, 15, 1000, 0.04),
            ("เต้าหู้ไข่", -2, 5, 8, 10),
            ("ถั่วฝักยาว", -1, 4, 500, 0.04),
            ("น้ำปลา", -30, 300, 1500, 0.05),
            ("น้ำตาลทราย", -30, 300, 2000, 0.03),
            ("แตงกวา", -1, 4, 200, 0.03),
        ]
        for name, recv, useby, qty, cost in lots:
            cur.execute(
                "INSERT INTO lots(ingredient_id,received_date,use_by,qty_left,unit_cost,note) "
                "VALUES (%s,%s,%s,%s,%s,%s)",
                (ing[name], d(recv), d(useby), qty, cost, "ข้อมูลจำลอง"),
            )
            lot_id = cur.lastrowid
            cur.execute(
                "INSERT INTO movements(ingredient_id,lot_id,type,qty,unit_cost,created_at,ref,reason) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                (ing[name], lot_id, "IN", qty, cost, d(recv) + " 08:00:00", "ยอดยกมา", "ข้อมูลจำลอง"),
            )

        # เมนู + สูตร
        menus = {
            ("M01", "ฟักทองผัดไข่"): [("ฟักทอง", 100), ("ไข่ไก่", 1), ("กระเทียม", 5), ("น้ำมันพืช", 10), ("ซอสหอยนางรม", 10)],
            ("M02", "ผัดผักบุ้งไฟแดง"): [("ผักบุ้ง", 150), ("กระเทียม", 5), ("พริกขี้หนู", 3), ("น้ำมันพืช", 10), ("ซอสหอยนางรม", 15)],
            ("M03", "ข้าวกะเพราหมูสับ"): [("หมูสับ", 100), ("ใบกะเพรา", 10), ("พริกขี้หนู", 5), ("กระเทียม", 5), ("ข้าวสาร", 120), ("น้ำมันพืช", 10), ("น้ำปลา", 10)],
            ("M04", "ไข่เจียวหมูสับ"): [("ไข่ไก่", 2), ("หมูสับ", 40), ("น้ำมันพืช", 30), ("น้ำปลา", 5)],
            ("M05", "ผัดคะน้าหมูสับ"): [("คะน้า", 150), ("หมูสับ", 60), ("กระเทียม", 5), ("ซอสหอยนางรม", 15), ("น้ำมันพืช", 10)],
            ("M06", "ไก่ผัดมะเขือเทศ"): [("อกไก่", 100), ("มะเขือเทศ", 80), ("หอมหัวใหญ่", 40), ("น้ำมันพืช", 10), ("น้ำตาลทราย", 5)],
            ("M07", "แกงจืดเต้าหู้หมูสับ"): [("เต้าหู้ไข่", 1), ("หมูสับ", 50), ("ตำลึง", 30), ("น้ำปลา", 10)],
            ("M08", "ผัดถั่วฝักยาวหมูสับ"): [("ถั่วฝักยาว", 120), ("หมูสับ", 50), ("กระเทียม", 5), ("น้ำปลา", 10), ("น้ำมันพืช", 10)],
            ("M09", "ไข่ผัดมะเขือเทศ"): [("ไข่ไก่", 2), ("มะเขือเทศ", 100), ("หอมหัวใหญ่", 30), ("น้ำมันพืช", 10), ("น้ำตาลทราย", 5)],
            ("M10", "แกงจืดฟักทองหมูสับ"): [("ฟักทอง", 120), ("หมูสับ", 50), ("น้ำปลา", 10)],
        }
        for (code, name), items in menus.items():
            cur.execute("INSERT INTO menus(code,name) VALUES (%s,%s)", (code, name))
            mid = cur.lastrowid
            for ing_name, qty in items:
                cur.execute(
                    "INSERT INTO recipe_items(menu_id,ingredient_id,qty_per_dish) VALUES (%s,%s,%s)",
                    (mid, ing[ing_name], qty),
                )

        # เกษตรกร
        farmers = [
            ("กลุ่มเกษตรกรบ้านหนองบัว (จำลอง)", "ต.หนองบัว", "081-000-0001"),
            ("ฟาร์มไข่ลุงชัย (จำลอง)", "ต.ท่าช้าง", "081-000-0002"),
            ("สวนผักป้าแดง (จำลอง)", "ต.บ้านใหม่", "081-000-0003"),
            ("วิสาหกิจชุมชนผักปลอดภัย (จำลอง)", "ต.โนนสูง", "081-000-0004"),
            ("ฟาร์มหมูพี่เอก (จำลอง)", "ต.หนองบัว", "081-000-0005"),
        ]
        cur.executemany("INSERT INTO farmers(name,area,contact) VALUES (%s,%s,%s)", farmers)
        cur.execute("SELECT id FROM farmers ORDER BY id")
        fid = [row["id"] for row in cur.fetchall()]

        # ผลผลิตพร้อมขาย
        produce = [
            (0, "ฟักทอง", 30, "กก.", 50, 0),
            (2, "ฟักทอง", 35, "กก.", 20, 1),
            (1, "ไข่ไก่", 5, "ฟอง", 300, 0),
            (3, "ไข่ไก่", 5.5, "ฟอง", 200, 0),
            (2, "ผักบุ้ง", 30, "กก.", 15, 0),
            (2, "คะน้า", 40, "กก.", 10, 0),
            (3, "ถั่วฝักยาว", 40, "กก.", 10, 1),
            (3, "ตำลึง", 50, "กก.", 5, 0),
            (3, "มะเขือเทศ", 40, "กก.", 15, 0),
            (0, "แตงกวา", 25, "กก.", 20, 0),
            (4, "หมูสับ", 140, "กก.", 30, 0),
            (0, "ใบกะเพรา", 60, "กก.", 3, 0),
        ]
        for f, name, price, unit, qty, ready in produce:
            cur.execute(
                "INSERT INTO produce(farmer_id,ingredient_id,price,sell_unit,qty_available,ready_date,updated_at) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s)",
                (fid[f], ing[name], price, unit, qty, d(ready), now_str()),
            )

        # ประวัติซื้อย้อนหลัง
        history = [(1, -7, "ไข่ไก่", 60, 5), (2, -5, "ผักบุ้ง", 2000, 0.03), (4, -3, "หมูสับ", 3000, 0.14)]
        for f, day, name, qty, price in history:
            cur.execute(
                "INSERT INTO purchase_orders(farmer_id,created_at,status,received_at) VALUES (%s,%s,%s,%s)",
                (fid[f], d(day) + " 09:00:00", "RECEIVED", d(day) + " 15:00:00"),
            )
            cur.execute(
                "INSERT INTO po_items(po_id,ingredient_id,qty,unit_price) VALUES (%s,%s,%s,%s)",
                (cur.lastrowid, ing[name], qty, price),
            )

        cur.close()


def init_db():
    # Older SQL exports include a trigger that changes stock a second time.
    # The application owns stock updates and their movement log atomically.
    with get_conn() as conn:
        conn.execute("DROP TRIGGER IF EXISTS trg_movement_after_insert")
    create_tables()
    if is_empty():
        seed_demo_data()


if __name__ == "__main__":
    # รันไฟล์นี้ตรง ๆ เพื่อสร้างตาราง + ใส่ข้อมูลจำลองใหม่
    try:
        init_db()
        print("สร้างฐานข้อมูล MySQL + demo data เรียบร้อย")
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print("เชื่อมต่อไม่ได้: ตรวจสอบ user/password ใน DB_CONFIG")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            print("Database ไม่มีอยู่: สร้าง database ก่อน (CREATE DATABASE community_menu)")
        else:
            print(f"MySQL Error: {err}")
        sys.exit(1)
