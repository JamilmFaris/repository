import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  static const tables = [
    'invoice_items', 'invoices', 'products', 'payments', 'returns', 'customers',
    'purchase_items', 'purchase_invoices', 'supplier_payments', 'suppliers',
    'expenses', 'reservation_items', 'reservations', 'coupons', 'capital_snapshots', 'receipts',
    'cash_movements', 'cash_counts', 'supplier_return_items', 'supplier_returns',
  ];

  static const _schemaVersion = 4;

  /// ترقيات تراكمية: تضيف أعمدة/جداول فقط، فلا تُفقد أي بيانات موجودة.
  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 2 && to >= 2) {
      const stmts = [
        // مهمة 3: عرض الشركة + مهمة 8: تثبيت السعر
        "ALTER TABLE products ADD COLUMN companyBuyQty INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE products ADD COLUMN companyFreeQty INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE products ADD COLUMN lockMode TEXT NOT NULL DEFAULT 'none'",
        "ALTER TABLE products ADD COLUMN lockBuyRate REAL NOT NULL DEFAULT 0",
        "ALTER TABLE products ADD COLUMN lockSellRate REAL NOT NULL DEFAULT 0",
        // نوع الهدية في الفاتورة: mine (حسابي) | company (الشركة)
        "ALTER TABLE invoice_items ADD COLUMN giftType TEXT NOT NULL DEFAULT 'mine'",
        // هدايا الشركة عند الشراء
        "ALTER TABLE purchase_items ADD COLUMN giftQty INTEGER NOT NULL DEFAULT 0",
        // لقطات رأس المال الشهرية (مهمة 5)
        '''CREATE TABLE IF NOT EXISTS capital_snapshots(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          month TEXT NOT NULL UNIQUE,
          capitalUsd REAL NOT NULL,
          rate REAL NOT NULL,
          capitalSyp REAL NOT NULL,
          date TEXT NOT NULL
        )''',
      ];
      for (final s in stmts) {
        await db.execute(s);
      }
    }
    if (from < 3 && to >= 3) {
      // وصولات الدفع (مهمة 9)
      await db.execute('''CREATE TABLE IF NOT EXISTS receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number INTEGER NOT NULL,
        customerId INTEGER,
        customerName TEXT NOT NULL,
        amount REAL NOT NULL,
        purpose TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        paymentId INTEGER
      )''');
    }
    if (from < 4 && to >= 4) {
      const stmts = [
        // الصندوق (مهمة 12)
        '''CREATE TABLE IF NOT EXISTS cash_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          reason TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL
        )''',
        '''CREATE TABLE IF NOT EXISTS cash_counts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          theoretical REAL NOT NULL,
          actual REAL NOT NULL,
          diff REAL NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )''',
        // شحن وجمارك (مهمة 13)
        "ALTER TABLE purchase_invoices ADD COLUMN shippingCost REAL NOT NULL DEFAULT 0",
        "ALTER TABLE purchase_invoices ADD COLUMN otherCost REAL NOT NULL DEFAULT 0",
        "ALTER TABLE purchase_items ADD COLUMN extraCost REAL NOT NULL DEFAULT 0",
        // مرتجعات الموردين (مهمة 14)
        '''CREATE TABLE IF NOT EXISTS supplier_returns(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplierId INTEGER NOT NULL,
          date TEXT NOT NULL,
          reason TEXT NOT NULL DEFAULT '',
          note TEXT NOT NULL DEFAULT '',
          total REAL NOT NULL DEFAULT 0
        )''',
        '''CREATE TABLE IF NOT EXISTS supplier_return_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          returnId INTEGER NOT NULL,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unitPrice REAL NOT NULL
        )''',
      ];
      for (final s in stmts) {
        await db.execute(s);
      }
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'makhzani.db');
    return await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        const schema = [
          '''CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buyPrice REAL NOT NULL,
            sellPrice REAL NOT NULL,
            createdAt TEXT NOT NULL,
            priceMode TEXT NOT NULL DEFAULT 'SYP',
            buyPriceUsd REAL NOT NULL DEFAULT 0,
            sellPriceUsd REAL NOT NULL DEFAULT 0,
            offerBuyQty INTEGER NOT NULL DEFAULT 0,
            offerFreeQty INTEGER NOT NULL DEFAULT 0
          )''',
          '''CREATE TABLE invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT NOT NULL,
            customerName TEXT NOT NULL,
            date TEXT NOT NULL,
            customerId INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            discountType TEXT NOT NULL DEFAULT 'none',
            discountValue REAL NOT NULL DEFAULT 0,
            couponCode TEXT,
            paidAmount REAL
          )''',
          '''CREATE TABLE invoice_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceId INTEGER NOT NULL,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buyPrice REAL NOT NULL,
            sellPrice REAL NOT NULL,
            discountType TEXT NOT NULL DEFAULT 'none',
            discountValue REAL NOT NULL DEFAULT 0,
            isGift INTEGER NOT NULL DEFAULT 0,
            returnedQty INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
          )''',
          '''CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            createdAt TEXT NOT NULL
          )''',
          '''CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId INTEGER,
            invoiceId INTEGER,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )''',
          '''CREATE TABLE returns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoiceId INTEGER NOT NULL,
            itemId INTEGER,
            productId INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            refundAmount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )''',
          '''CREATE TABLE suppliers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            createdAt TEXT NOT NULL
          )''',
          '''CREATE TABLE purchase_invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId INTEGER NOT NULL,
            number TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            paidAmount REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT ''
          )''',
          '''CREATE TABLE purchase_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchaseId INTEGER NOT NULL,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buyPrice REAL NOT NULL
          )''',
          '''CREATE TABLE supplier_payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId INTEGER NOT NULL,
            purchaseId INTEGER,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )''',
          '''CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            invoiceId INTEGER
          )''',
          '''CREATE TABLE reservations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerName TEXT NOT NULL,
            customerId INTEGER,
            date TEXT NOT NULL,
            dueDate TEXT,
            notes TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'open'
          )''',
          '''CREATE TABLE reservation_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reservationId INTEGER NOT NULL,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL
          )''',
          '''CREATE TABLE coupons(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            value REAL NOT NULL,
            expiry TEXT,
            active INTEGER NOT NULL DEFAULT 1
          )''',
        ];
        for (final sql in schema) {
          await db.execute(sql);
        }
        // قاعدة جديدة: ننشئ مخطط الإصدار 1 ثم نطبّق الترقيات بالترتيب
        await _migrate(db, 1, v);
      },
      onUpgrade: (db, from, to) => _migrate(db, from, to),
    );
  }

  Future<void> deleteAll() async {
    final db = await database;
    for (final t in tables) {
      await db.delete(t);
    }
  }
}
