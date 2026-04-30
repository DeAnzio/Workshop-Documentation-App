import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class BackendService {
  // Session storage keys
  static const String _currentUserIdKey = 'current_user_id';
  static const String _currentUserEmailKey = 'current_user_email';
  static const String _currentUserNameKey = 'current_user_name';
  static const String _sessionExpiryKey = 'session_expiry';
  static const String _persistentLoginKey = 'persistent_login';
  static const String _sessionExpiredKey = 'session_expired';
  static const String _appLockRequiredKey = 'app_lock_required';
  static const Duration _sessionDuration = Duration(hours: 24);

  static Database? _db;

  static Future<void> initialize() async {
    await _openDatabase();
  }

  static Future<Database> _openDatabase() async {
    if (_db != null) return _db!;

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'anzioworkshopapp.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onOpen: (db) async {
        await _updateSchema(db);
      },
    );
    return _db!;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS technicians (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        avatar_url TEXT,
        no_hp TEXT,
        kesanpesan TEXT,
        preferred_time TEXT,
        currency TEXT DEFAULT 'IDR',
        pin_hash TEXT,
        pin_attempts INTEGER DEFAULT 0,
        pin_locked_until TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        no_hp TEXT NOT NULL UNIQUE,
        alamat TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_tiket TEXT NOT NULL,
        customer_id INTEGER NOT NULL,
        technician_id INTEGER NOT NULL,
        jenis_perangkat TEXT,
        merek_model TEXT,
        serial_number TEXT,
        kondisi_fisik TEXT,
        kelengkapan TEXT,
        password_pin TEXT,
        keluhan TEXT,
        diagnosa TEXT,
        jenis_service TEXT,
        prioritas TEXT DEFAULT 'normal',
        estimasi_biaya REAL,
        biaya_akhir REAL,
        status_bayar TEXT DEFAULT 'belum',
        nominal_dp REAL,
        status_service TEXT DEFAULT 'masuk',
        currency TEXT DEFAULT 'IDR',
        tgl_masuk TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(customer_id) REFERENCES customers(id),
        FOREIGN KEY(technician_id) REFERENCES technicians(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_order_id INTEGER NOT NULL,
        photo_url TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(service_order_id) REFERENCES service_orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS service_spareparts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_order_id INTEGER NOT NULL,
        nama TEXT NOT NULL,
        kode TEXT,
        qty INTEGER NOT NULL,
        harga REAL NOT NULL,
        photo_url TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(service_order_id) REFERENCES service_orders(id)
      )
    ''');
  }

  static Future<void> _updateSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(technicians)');
    final hasKesanPesan = columns.any(
      (column) => column['name'] == 'kesanpesan',
    );
    if (!hasKesanPesan) {
      try {
        await db.execute('ALTER TABLE technicians ADD COLUMN kesanpesan TEXT');
      } catch (_) {
        // ignore if column already exists or sqlite does not support this addition
      }
    }
    final hasPreferredTime = columns.any(
      (column) => column['name'] == 'preferred_time',
    );
    if (!hasPreferredTime) {
      try {
        await db.execute('ALTER TABLE technicians ADD COLUMN preferred_time TEXT');
      } catch (_) {
        // ignore if column already exists or sqlite does not support this addition
      }
    }

    final hasCurrencyColumn = columns.any(
      (column) => column['name'] == 'currency',
    );
    if (!hasCurrencyColumn) {
      try {
        await db.execute("ALTER TABLE technicians ADD COLUMN currency TEXT DEFAULT 'IDR'");
      } catch (_) {
        // ignore if column already exists or sqlite does not support this addition
      }
    }

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'service_spareparts'",
    );
    if (tables.isEmpty) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS service_spareparts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_order_id INTEGER NOT NULL,
            nama TEXT NOT NULL,
            kode TEXT,
            qty INTEGER NOT NULL,
            harga REAL NOT NULL,
            photo_url TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(service_order_id) REFERENCES service_orders(id)
          )
        ''');
      } catch (_) {
        // ignore if table creation fails on older sqlite versions
      }
    } else {
      final sparepartColumns = await db.rawQuery(
        'PRAGMA table_info(service_spareparts)',
      );
      final hasPhotoUrl = sparepartColumns.any(
        (column) => column['name'] == 'photo_url',
      );
      if (!hasPhotoUrl) {
        try {
          await db.execute(
            'ALTER TABLE service_spareparts ADD COLUMN photo_url TEXT',
          );
        } catch (_) {
          // ignore if column addition fails on older sqlite versions
        }
      }
    }
  }

  static Future<File> _localFile(
    String fileName, {
    String folder = 'uploads',
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final folderPath = p.join(directory.path, folder);
    await Directory(folderPath).create(recursive: true);
    return File(p.join(folderPath, fileName));
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Get current logged-in user ID from local storage
  static Future<String?> get currentUserId async {
    if (!await validateSession()) return null;
    final prefs = await _prefs();
    return prefs.getString(_currentUserIdKey);
  }

  /// Get current logged-in user email from local storage
  static Future<String?> get currentUserEmail async {
    if (!await validateSession()) return null;
    final prefs = await _prefs();
    return prefs.getString(_currentUserEmailKey);
  }

  /// Get current logged-in user name from local storage
  static Future<String?> get currentUserName async {
    if (!await validateSession()) return null;
    final prefs = await _prefs();
    return prefs.getString(_currentUserNameKey);
  }

  /// Get session expiry date from local storage
  static Future<DateTime?> get _sessionExpiry async {
    final prefs = await _prefs();
    final expiryMillis = prefs.getInt(_sessionExpiryKey);
    if (expiryMillis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiryMillis);
  }

  static Future<void> _saveSessionExpiry(DateTime expiry) async {
    final prefs = await _prefs();
    await prefs.setInt(_sessionExpiryKey, expiry.millisecondsSinceEpoch);
  }

  /// Check whether the current session is still valid
  static Future<bool> get isSessionValid async {
    final expiry = await _sessionExpiry;
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Check if session has expired (but user still has persistent login)
  static Future<bool> get isSessionExpired async {
    final valid = await isSessionValid;
    final persistent = await hasPersistentLogin;
    return !valid && persistent;
  }

  /// Check if user has persistent login (was logged in before)
  static Future<bool> get hasPersistentLogin async {
    final prefs = await _prefs();
    return prefs.getBool(_persistentLoginKey) ?? false;
  }

  /// Check if app lock is required after closing/backgrounding the app
  static Future<bool> get isAppLockRequired async {
    final prefs = await _prefs();
    return prefs.getBool(_appLockRequiredKey) ?? false;
  }

  /// Set whether app lock is required
  static Future<void> setAppLockRequired(bool required) async {
    final prefs = await _prefs();
    await prefs.setBool(_appLockRequiredKey, required);
  }

  /// Check if user is logged in and session has not expired
  static Future<bool> get isLoggedIn async {
    final valid = await isSessionValid;
    if (!valid) {
      return false;
    }

    final prefs = await _prefs();
    return prefs.containsKey(_currentUserIdKey);
  }

  /// Get technician ID without session validation (for re-authentication)
  static Future<String?> getTechnicianIdWithoutSessionCheck() async {
    final prefs = await _prefs();
    return prefs.getString(_currentUserIdKey);
  }

  /// Refresh session expiry without clearing user data
  static Future<void> refreshSession() async {
    final expiry = DateTime.now().add(_sessionDuration);
    final prefs = await _prefs();
    await Future.wait([
      _saveSessionExpiry(expiry),
      prefs.setBool(_sessionExpiredKey, false),
      prefs.setBool(_appLockRequiredKey, false),
    ]);
    print('Session refreshed, expires at $expiry');
  }

  /// Mark session as expired for verification
  static Future<void> markSessionExpired() async {
    final prefs = await _prefs();
    await prefs.setBool(_sessionExpiredKey, true);
  }

  /// Check if session is marked as expired
  static Future<bool> checkSessionExpired() async {
    final prefs = await _prefs();
    return prefs.getBool(_sessionExpiredKey) ?? false;
  }

  /// Make sure session is valid, otherwise mark for re-authentication
  static Future<bool> validateSession() async {
    final valid = await isSessionValid;
    if (!valid) {
      await markSessionExpired();
      return false;
    }
    return true;
  }

  /// Register new technician with manual password hashing
  /// Returns true when registration succeeded
  static Future<bool> createTechnician(
    String name,
    String email,
    String password,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      print('Registration failed: all fields required');
      return false;
    }

    try {
      final db = await _openDatabase();
      final existing = await db.query(
        'technicians',
        where: 'email = ?',
        whereArgs: [email.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        print('Registration failed: email already exists');
        return false;
      }

      final hashedPassword = _hashValue(password);
      await db.insert('technicians', {
        'name': name,
        'email': email.toLowerCase(),
        'password': hashedPassword,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Registration failed: $e');
      return false;
    }
  }

  /// Manual login - hash password and verify against local SQLite database
  /// Returns true when login succeeded
  static Future<bool> signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      print('Login failed: email and password required');
      return false;
    }

    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        where: 'email = ?',
        whereArgs: [email.toLowerCase()],
      );

      if (rows.isEmpty) {
        print('Login failed: technician not found');
        return false;
      }

      final technician = rows.first;
      final hashedPassword = _hashValue(password);
      if (technician['password'] != hashedPassword) {
        print('Login failed: invalid password');
        return false;
      }

      final prefs = await _prefs();
      final userId = technician['id'].toString();
      final userName = technician['name']?.toString() ?? 'Unknown';
      final expiry = DateTime.now().add(_sessionDuration);

      await Future.wait([
        prefs.setString(_currentUserIdKey, userId),
        prefs.setString(_currentUserEmailKey, email.toLowerCase()),
        prefs.setString(_currentUserNameKey, userName),
        prefs.setBool(_persistentLoginKey, true),
        prefs.setBool(_sessionExpiredKey, false),
        prefs.setBool(_appLockRequiredKey, false),
      ]);
      await _saveSessionExpiry(expiry);

      print('Login successful for user: $email, session expires at $expiry');
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout - clear session and persistent login from local storage
  static Future<void> signOut() async {
    try {
      final prefs = await _prefs();
      await Future.wait([
        prefs.remove(_currentUserIdKey),
        prefs.remove(_currentUserEmailKey),
        prefs.remove(_currentUserNameKey),
        prefs.remove(_sessionExpiryKey),
        prefs.remove(_persistentLoginKey),
        prefs.remove(_sessionExpiredKey),
        prefs.remove(_appLockRequiredKey),
      ]);
      print('Logout successful');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Clear session expiry but keep persistent login (for session timeout)
  static Future<void> clearSessionOnly() async {
    try {
      final prefs = await _prefs();
      await Future.wait([
        prefs.remove(_sessionExpiryKey),
        prefs.setBool(_sessionExpiredKey, true),
        prefs.setBool(_appLockRequiredKey, true),
      ]);
      print('Session cleared for re-authentication');
    } catch (e) {
      print('Clear session error: $e');
    }
  }

  /// Fetch technician row by email
  static Future<Map<String, dynamic>?> fetchTechnicianByEmail(
    String email,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        where: 'email = ?',
        whereArgs: [email.toLowerCase()],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('Fetch technician error: $e');
      return null;
    }
  }

  /// Fetch technician row by id
  static Future<Map<String, dynamic>?> fetchTechnicianById(String id) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('Fetch technician by id error: $e');
      return null;
    }
  }

  /// Fetch customer row by phone
  static Future<Map<String, dynamic>?> fetchCustomerByPhone(
    String phone,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'customers',
        where: 'no_hp = ?',
        whereArgs: [phone],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('Fetch customer error: $e');
      return null;
    }
  }

  /// Fetch customer row by id
  static Future<Map<String, dynamic>?> fetchCustomerById(String id) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('Fetch customer by id error: $e');
      return null;
    }
  }

  /// Create or reuse customer record based on phone number
  static Future<String?> createCustomer(
    String nama,
    String noHp, {
    String? alamat,
  }) async {
    try {
      final existing = await fetchCustomerByPhone(noHp);
      if (existing != null) {
        return existing['id']?.toString();
      }

      final db = await _openDatabase();
      final id = await db.insert('customers', {
        'nama': nama,
        'no_hp': noHp,
        'alamat': alamat,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return id.toString();
    } catch (e) {
      print('Create customer failed: $e');
      return null;
    }
  }

  static String _generateTicketNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = now.millisecondsSinceEpoch.toString().substring(8);
    return 'SRV-$datePart-$randomPart';
  }

  /// Insert service order for a customer and technician
  static Future<String?> insertServiceOrder({
    required String customerId,
    required String technicianId,
    required String jenisDevice,
    required String merekModel,
    String? serialNumber,
    String? kondisiFisik,
    String? kelengkapan,
    required String passwordPin,
    required String keluhan,
    String? jenisService,
    String prioritas = 'normal',
    double? estimasiBiaya,
    double? nominalDp,
    String currency = 'IDR',
  }) async {
    try {
      final db = await _openDatabase();
      final ticket = _generateTicketNumber();
      final id = await db.insert('service_orders', {
        'nomor_tiket': ticket,
        'customer_id': int.tryParse(customerId) ?? 0,
        'technician_id': int.tryParse(technicianId) ?? 0,
        'jenis_perangkat': jenisDevice,
        'merek_model': merekModel,
        'serial_number': serialNumber,
        'kondisi_fisik': kondisiFisik,
        'kelengkapan': kelengkapan,
        'password_pin': passwordPin,
        'keluhan': keluhan,
        'diagnosa': null,
        'jenis_service': jenisService,
        'prioritas': prioritas,
        'estimasi_biaya': estimasiBiaya,
        'nominal_dp': nominalDp,
        'currency': currency,
        'status_service': 'masuk',
        'status_bayar': 'belum',
        'tgl_masuk': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return id.toString();
    } catch (e) {
      print('Insert service order failed: $e');
      return null;
    }
  }

  /// Insert customer and service order records
  static Future<String?> insertCustomerData({
    required String namaPelanggan,
    required String noHp,
    String? alamat,
    required String jenisDevice,
    required String merekModel,
    String? serialNumber,
    String? kondisiFisik,
    String? kelengkapan,
    required String password,
    required String keluhan,
    required String serviceType,
    String prioritas = 'normal',
    double? estimasiBiaya,
    double? nominalDp,
    required String technicianId,
    String currency = 'IDR',
  }) async {
    try {
      final customerId = await createCustomer(
        namaPelanggan,
        noHp,
        alamat: alamat,
      );
      if (customerId == null) {
        print('Insert customer data failed: unable to create customer');
        return null;
      }

      final serviceOrderId = await insertServiceOrder(
        customerId: customerId,
        technicianId: technicianId,
        jenisDevice: jenisDevice,
        merekModel: merekModel,
        serialNumber: serialNumber,
        kondisiFisik: kondisiFisik,
        kelengkapan: kelengkapan,
        passwordPin: password,
        keluhan: keluhan,
        jenisService: serviceType,
        prioritas: prioritas,
        estimasiBiaya: estimasiBiaya,
        nominalDp: nominalDp,
        currency: currency,
      );

      if (serviceOrderId == null) {
        print('Insert customer data failed: unable to create service order');
      }
      return serviceOrderId;
    } catch (e) {
      print('Insert customer data failed: $e');
      return null;
    }
  }

  /// Get technician ID for current authenticated user
  static Future<String?> getCurrentTechnicianId() async {
    final userId = await currentUserId;
    if (userId == null) {
      print('getCurrentTechnicianId: no user logged in');
      return null;
    }
    return userId;
  }

  /// Upload image to local storage and return file path
  static Future<String?> uploadImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final file = await _localFile(fileName, folder: 'uploads');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      print('Upload image failed: $e');
      return null;
    }
  }

  /// Upload profile avatar to local storage and return file path
  static Future<String?> uploadProfileAvatar(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final file = await _localFile(fileName, folder: 'avatars');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      print('Upload profile avatar failed: $e');
      return null;
    }
  }

  /// Fetch service orders for a technician
  static Future<List<Map<String, dynamic>>> fetchServiceOrdersForTechnician(
    String technicianId, {
    bool excludeFinished = true,
  }) async {
    try {
      final db = await _openDatabase();
      final whereClauses = <String>['technician_id = ?'];
      final whereArgs = <Object>[int.tryParse(technicianId) ?? 0];
      if (excludeFinished) {
        whereClauses.add("status_service NOT IN ('selesai','ambil')");
      }
      final rows = await db.rawQuery('''
        SELECT so.*, c.nama AS customer_nama, c.no_hp AS customer_no_hp, c.alamat AS customer_alamat
        FROM service_orders so
        JOIN customers c ON so.customer_id = c.id
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY so.tgl_masuk DESC
        ''', whereArgs);
      return rows.map((row) {
        final item = Map<String, dynamic>.from(row);
        item['customers'] = {
          'nama': row['customer_nama'],
          'no_hp': row['customer_no_hp'],
          'alamat': row['customer_alamat'],
        };
        return item;
      }).toList();
    } catch (e) {
      print('Fetch service orders failed: $e');
      return [];
    }
  }

  /// Update service order
  static Future<bool> updateServiceOrder(
    String serviceOrderId, {
    String? statusService,
    String? diagnosa,
    double? biayaAkhir,
    String? statusBayar,
    String? jenisService,
    double? estimasiBiaya,
    String? prioritas,
    String? kondisiFisik,
    String? kelengkapan,
    String? keluhan,
    String? currency,
  }) async {
    try {
      final db = await _openDatabase();
      final updateData = <String, Object?>{};
      if (statusService != null) updateData['status_service'] = statusService;
      if (diagnosa != null) updateData['diagnosa'] = diagnosa;
      if (biayaAkhir != null) updateData['biaya_akhir'] = biayaAkhir;
      if (statusBayar != null) updateData['status_bayar'] = statusBayar;
      if (jenisService != null) updateData['jenis_service'] = jenisService;
      if (estimasiBiaya != null) updateData['estimasi_biaya'] = estimasiBiaya;
      if (prioritas != null) updateData['prioritas'] = prioritas;
      if (kondisiFisik != null) updateData['kondisi_fisik'] = kondisiFisik;
      if (kelengkapan != null) updateData['kelengkapan'] = kelengkapan;
      if (keluhan != null) updateData['keluhan'] = keluhan;
      if (currency != null) updateData['currency'] = currency;
      if (updateData.isEmpty) return true;
      updateData['updated_at'] = DateTime.now().toIso8601String();
      final count = await db.update(
        'service_orders',
        updateData,
        where: 'id = ?',
        whereArgs: [int.tryParse(serviceOrderId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Update service order failed: $e');
      return false;
    }
  }

  /// Delete service order
  static Future<bool> deleteServiceOrder(String serviceOrderId) async {
    try {
      final db = await _openDatabase();
      await db.delete(
        'service_photos',
        where: 'service_order_id = ?',
        whereArgs: [int.tryParse(serviceOrderId) ?? 0],
      );
      final count = await db.delete(
        'service_orders',
        where: 'id = ?',
        whereArgs: [int.tryParse(serviceOrderId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Delete service order failed: $e');
      return false;
    }
  }

  /// Insert photo record
  static Future<bool> insertServicePhoto(
    String serviceOrderId,
    String photoUrl,
  ) async {
    try {
      final db = await _openDatabase();
      await db.insert('service_photos', {
        'service_order_id': int.tryParse(serviceOrderId) ?? 0,
        'photo_url': photoUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Insert service photo failed: $e');
      return false;
    }
  }

  /// Get service photos for a service order
  static Future<List<Map<String, dynamic>>> getServicePhotos(
    String serviceOrderId,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'service_photos',
        where: 'service_order_id = ?',
        whereArgs: [int.tryParse(serviceOrderId) ?? 0],
        orderBy: 'created_at DESC',
      );
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      print('Get service photos failed: $e');
      return [];
    }
  }

  /// Insert sparepart entry for a service order
  static Future<String?> insertServiceSparepart(
    String serviceOrderId, {
    required String nama,
    String? kode,
    required int qty,
    required double harga,
    String? photoUrl,
  }) async {
    try {
      final db = await _openDatabase();
      final data = <String, Object?>{
        'service_order_id': int.tryParse(serviceOrderId) ?? 0,
        'nama': nama,
        'kode': kode,
        'qty': qty,
        'harga': harga,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (photoUrl != null) data['photo_url'] = photoUrl;
      final id = await db.insert('service_spareparts', data);
      return id.toString();
    } catch (e) {
      print('Insert service sparepart failed: $e');
      return null;
    }
  }

  /// Get spareparts for a service order
  static Future<List<Map<String, dynamic>>> fetchServiceSpareparts(
    String serviceOrderId,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'service_spareparts',
        where: 'service_order_id = ?',
        whereArgs: [int.tryParse(serviceOrderId) ?? 0],
        orderBy: 'created_at DESC',
      );
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      print('Fetch service spareparts failed: $e');
      return [];
    }
  }

  /// Get total sparepart cost for a service order
  static Future<double> fetchServiceSparepartsTotal(
    String serviceOrderId,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.rawQuery(
        'SELECT SUM(qty * harga) AS total FROM service_spareparts WHERE service_order_id = ?',
        [int.tryParse(serviceOrderId) ?? 0],
      );
      final total = rows.first['total'];
      if (total == null) return 0.0;
      return (total as num).toDouble();
    } catch (e) {
      print('Fetch service spareparts total failed: $e');
      return 0.0;
    }
  }

  /// Update a sparepart entry for a service order
  static Future<bool> updateServiceSparepart(
    String sparepartId, {
    String? nama,
    String? kode,
    int? qty,
    double? harga,
    String? photoUrl,
  }) async {
    try {
      final db = await _openDatabase();
      final updateData = <String, Object?>{};
      if (nama != null) updateData['nama'] = nama;
      if (kode != null) updateData['kode'] = kode;
      if (qty != null) updateData['qty'] = qty;
      if (harga != null) updateData['harga'] = harga;
      if (photoUrl != null) updateData['photo_url'] = photoUrl;
      if (updateData.isEmpty) return false;
      updateData['updated_at'] = DateTime.now().toIso8601String();
      final count = await db.update(
        'service_spareparts',
        updateData,
        where: 'id = ?',
        whereArgs: [int.tryParse(sparepartId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Update service sparepart failed: $e');
      return false;
    }
  }

  /// Delete a sparepart entry
  static Future<bool> deleteServiceSparepart(String sparepartId) async {
    try {
      final db = await _openDatabase();
      final count = await db.delete(
        'service_spareparts',
        where: 'id = ?',
        whereArgs: [int.tryParse(sparepartId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Delete service sparepart failed: $e');
      return false;
    }
  }

  /// Update technician profile
  static Future<bool> updateTechnicianProfile(
    String technicianId, {
    String? name,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? kesanPesan,
    String? preferredTime,
    String? currency,
    bool? securityEnabled,
  }) async {
    try {
      final db = await _openDatabase();
      final updateData = <String, Object?>{};
      if (name != null) updateData['name'] = name;
      if (phoneNumber != null) updateData['no_hp'] = phoneNumber;
      if (profilePhotoUrl != null) updateData['avatar_url'] = profilePhotoUrl;
      if (kesanPesan != null) updateData['kesanpesan'] = kesanPesan;
      if (preferredTime != null) updateData['preferred_time'] = preferredTime;
      if (currency != null) updateData['currency'] = currency;
      if (updateData.isEmpty) return false;
      updateData['updated_at'] = DateTime.now().toIso8601String();
      final count = await db.update(
        'technicians',
        updateData,
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Update technician profile failed: $e');
      return false;
    }
  }

  static Future<bool> saveTechnicianFeedback(
    String technicianId,
    String feedback,
  ) async {
    try {
      final db = await _openDatabase();
      final count = await db.update(
        'technicians',
        {
          'kesanpesan': feedback,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      return count > 0;
    } catch (e) {
      print('Save technician feedback failed: $e');
      return false;
    }
  }

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp.toUtc();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<bool> _updateTechnicianPinState(
    String technicianId, {
    String? pinHash,
    bool clearPinHash = false,
    int? pinAttempts,
    bool clearPinAttempts = false,
    DateTime? pinLockedUntil,
    bool clearPinLockedUntil = false,
  }) async {
    try {
      final db = await _openDatabase();
      final fields = <String, Object?>{};
      if (clearPinHash) {
        fields['pin_hash'] = null;
      } else if (pinHash != null) {
        fields['pin_hash'] = pinHash;
      }
      if (clearPinAttempts) {
        fields['pin_attempts'] = 0;
      } else if (pinAttempts != null) {
        fields['pin_attempts'] = pinAttempts;
      }
      if (clearPinLockedUntil) {
        fields['pin_locked_until'] = null;
      } else if (pinLockedUntil != null) {
        fields['pin_locked_until'] = pinLockedUntil.toUtc().toIso8601String();
      }
      if (fields.isEmpty) return true;
      await db.update(
        'technicians',
        fields,
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      return true;
    } catch (e) {
      print('Update technician PIN state failed: $e');
      return false;
    }
  }

  static Future<bool> saveTechnicianPin(String technicianId, String pin) async {
    try {
      final pinHash = _hashPin(pin);
      final success = await _updateTechnicianPinState(
        technicianId,
        pinHash: pinHash,
        pinAttempts: 0,
        clearPinAttempts: true,
        clearPinLockedUntil: true,
      );
      return success;
    } catch (e) {
      print('Save technician PIN failed: $e');
      return false;
    }
  }

  static Future<String?> getTechnicianPinHash(String technicianId) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        columns: ['pin_hash'],
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      if (rows.isEmpty) return null;
      return rows.first['pin_hash'] as String?;
    } catch (e) {
      print('Get technician PIN hash failed: $e');
      return null;
    }
  }

  static Future<bool> _resetPinAttempts(String technicianId) async {
    return await _updateTechnicianPinState(
      technicianId,
      pinAttempts: 0,
      clearPinLockedUntil: true,
    );
  }

  static Future<bool> _recordFailedPinAttempt(String technicianId) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        columns: ['pin_attempts'],
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      if (rows.isEmpty) {
        print('PIN state not found for technician: $technicianId');
        return false;
      }

      final currentAttempts = rows.first['pin_attempts'] as int? ?? 0;
      final nextAttempts = currentAttempts + 1;
      if (nextAttempts >= 3) {
        final lockedUntil = DateTime.now().toUtc().add(
          const Duration(seconds: 30),
        );
        return await _updateTechnicianPinState(
          technicianId,
          pinAttempts: 0,
          pinLockedUntil: lockedUntil,
        );
      }

      return await _updateTechnicianPinState(
        technicianId,
        pinAttempts: nextAttempts,
      );
    } catch (e) {
      print('Record failed PIN attempt failed: $e');
      return false;
    }
  }

  static Future<DateTime?> getTechnicianPinLockExpiration(
    String technicianId,
  ) async {
    try {
      final db = await _openDatabase();
      final rows = await db.query(
        'technicians',
        columns: ['pin_locked_until'],
        where: 'id = ?',
        whereArgs: [int.tryParse(technicianId) ?? 0],
      );
      if (rows.isEmpty) return null;
      return _parseTimestamp(rows.first['pin_locked_until']);
    } catch (e) {
      print('Get technician PIN lock expiration failed: $e');
      return null;
    }
  }

  static Future<bool> isTechnicianPinLocked(String technicianId) async {
    final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
    return lockedUntil != null && DateTime.now().toUtc().isBefore(lockedUntil);
  }

  static Future<int> getTechnicianPinLockRemainingSeconds(
    String technicianId,
  ) async {
    final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
    if (lockedUntil == null) return 0;
    final remaining = lockedUntil.difference(DateTime.now().toUtc()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  static Future<bool> verifyTechnicianPin(
    String technicianId,
    String pin,
  ) async {
    try {
      final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
      if (lockedUntil != null && DateTime.now().toUtc().isBefore(lockedUntil)) {
        return false;
      }

      final storedHash = await getTechnicianPinHash(technicianId);
      if (storedHash == null || storedHash.isEmpty) {
        return false;
      }

      final pinHash = _hashPin(pin);
      final isValid = storedHash == pinHash;
      if (isValid) {
        await _resetPinAttempts(technicianId);
        return true;
      }

      await _recordFailedPinAttempt(technicianId);
      return false;
    } catch (e) {
      print('Verify technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> lockTechnicianPin(
    String technicianId,
    DateTime lockedUntil,
  ) async {
    try {
      return await _updateTechnicianPinState(
        technicianId,
        pinLockedUntil: lockedUntil,
      );
    } catch (e) {
      print('Lock technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> clearTechnicianPin(String technicianId) async {
    try {
      return await _updateTechnicianPinState(
        technicianId,
        clearPinHash: true,
        clearPinAttempts: true,
        clearPinLockedUntil: true,
      );
    } catch (e) {
      print('Clear technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> isTechnicianPinSet(String technicianId) async {
    try {
      final pinHash = await getTechnicianPinHash(technicianId);
      return pinHash != null && pinHash.isNotEmpty;
    } catch (e) {
      print('Is technician PIN set failed: $e');
      return false;
    }
  }
}
