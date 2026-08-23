import 'package:collector_app/feature/database/database_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class CBDB {
  final tableName = 'cd_accounts';
  final repeatAccounts = 're-collected';

  /// Set to false at runtime if this device's SQLite build has no FTS5
  /// module, so searchAccounts() can skip straight to the LIKE fallback
  /// instead of hitting the same "no such module: fts5" error every time.
  bool _ftsAvailable = true;

  Future<void> createTable(Database database) async {
    await database.execute("""
 CREATE TABLE IF NOT EXISTS $tableName(
  total_record INT NULL,
    row_no INT NULL,
    id UUID PRIMARY KEY,
    client_id INT NULL,
    common_ac BOOLEAN NULL,
    br_id INT NULL,
    br_alias VARCHAR(10) NULL,
    center_id INT NULL,
    center_name VARCHAR(255) NULL,
    mf_grp_id INT NULL,
    mf_grp_name VARCHAR(255) NULL,
    iden_id INT NULL,
    id_no VARCHAR(50) NULL,
    account_id INT NULL,
    ac_no VARCHAR(50) NULL,
    ac_name VARCHAR(255) NULL,
    p_address TEXT NULL,
    t_address TEXT NULL,
    add_location VARCHAR(255) NULL,
    contact VARCHAR(50) NULL,
    account_type_id INT NULL,
    account_type_name VARCHAR(100) NULL,
    field_officer_id INT NULL,
    field_officer_name VARCHAR(100) NULL,
    ac_open_date DATE NULL,
    return_type_id INT NULL,
    return_type VARCHAR(50) NULL,
    rate_of_return DECIMAL(10,2) NULL,
    post_freq INT NULL,
    col_amt DECIMAL(10,2) NULL,
    balance DECIMAL(15,2) NULL,
    inst_amt DECIMAL(10,2) NULL,
    bal_date TEXT NULL,
    due_amt DECIMAL(10,2) NULL,
    maturity_date DATE NULL,
    pb_check_date DATE NULL,
    closed_status BOOLEAN NULL,
    status BOOLEAN NULL,
    remarks TEXT NULL,
    insert_user INT NULL,
    insert_date TEXT NULL,
    edit_user INT NULL,
    edit_date TEXT NULL,
    input_amount DECIMAL(15,2) NULL,
    col_remarks TEXT NULL,
    col_date_time TEXT NULL,
    col_location TEXT NULL,
    is_inserted BOOLEAN NULL,
    col_group_id TEXT NULL
 );
 CREATE INDEX idx_ac_name ON cd_accounts(ac_name);
 CREATE INDEX idx_iden_id ON cd_accounts(iden_id);
  CREATE INDEX idx_is_inserted ON $tableName(is_inserted);
 CREATE INDEX idx_id_no ON $tableName(id_no);
 CREATE INDEX idx_mf_grp_name ON $tableName(mf_grp_name);
 CREATE INDEX idx_ac_no ON $tableName(ac_no);
""");

    // Optional but recommended: full text search index for fast substring
    // search instead of a leading-wildcard LIKE '%...%' scan.
    //
    // Not every device's bundled SQLite has the FTS5 module compiled in
    // (some older Android system SQLite builds don't). If it's missing,
    // this throws "no such module: fts5" — caught here so table creation
    // (and therefore the whole app) doesn't crash. searchAccounts() then
    // uses the plain LIKE fallback automatically.
    try {
      await database.execute("""
 CREATE VIRTUAL TABLE IF NOT EXISTS cd_accounts_fts USING fts5(
   ac_name, id_no, ac_no, mf_grp_name, center_name,
   content='cd_accounts', content_rowid='rowid'
 );
""");

      // Keep the FTS index in sync automatically.
      await database.execute("""
 CREATE TRIGGER IF NOT EXISTS cd_accounts_ai AFTER INSERT ON cd_accounts BEGIN
   INSERT INTO cd_accounts_fts(rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
   VALUES (new.rowid, new.ac_name, new.id_no, new.ac_no, new.mf_grp_name, new.center_name);
 END;
""");
      await database.execute("""
 CREATE TRIGGER IF NOT EXISTS cd_accounts_ad AFTER DELETE ON cd_accounts BEGIN
   INSERT INTO cd_accounts_fts(cd_accounts_fts, rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
   VALUES('delete', old.rowid, old.ac_name, old.id_no, old.ac_no, old.mf_grp_name, old.center_name);
 END;
""");
      await database.execute("""
 CREATE TRIGGER IF NOT EXISTS cd_accounts_au AFTER UPDATE ON cd_accounts BEGIN
   INSERT INTO cd_accounts_fts(cd_accounts_fts, rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
   VALUES('delete', old.rowid, old.ac_name, old.id_no, old.ac_no, old.mf_grp_name, old.center_name);
   INSERT INTO cd_accounts_fts(rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
   VALUES (new.rowid, new.ac_name, new.id_no, new.ac_no, new.mf_grp_name, new.center_name);
 END;
""");
      _ftsAvailable = true;
    } catch (e) {
      // FTS5 module not available on this device — fine, we just fall
      // back to LIKE search everywhere. Nothing else breaks.
      _ftsAvailable = false;
    }
  }

  Map<String, dynamic> _rowFromApi(Map<String, dynamic> data) {
    return {
      'total_record': data['total_record'],
      'row_no': data['row_no'],
      'id': data['id'],
      'client_id': data['client_id'],
      'common_ac': data['common_ac'] == true ? 1 : 0,
      'br_id': data['br_id'],
      'br_alias': data['br_alias'],
      'center_id': data['center_id'],
      'center_name': data['center_name'],
      'mf_grp_id': data['mf_grp_id'],
      'mf_grp_name': data['mf_grp_name'],
      'iden_id': data['iden_id'],
      'id_no': data['id_no'],
      'account_id': data['account_id'],
      'ac_no': data['ac_no'],
      'ac_name': data['ac_name'],
      'p_address': data['p_address'],
      't_address': data['t_address'],
      'add_location': data['add_location'],
      'contact': data['contact'],
      'account_type_id': data['account_type_id'],
      'account_type_name': data['account_type_name'],
      'field_officer_id': data['field_officer_id'],
      'field_officer_name': data['field_officer_name'],
      'ac_open_date': data['ac_open_date'],
      'return_type_id': data['return_type_id'],
      'return_type': data['return_type'],
      'rate_of_return': data['rate_of_return'],
      'post_freq': data['post_freq'],
      'col_amt': data['col_amt'],
      'balance': data['balance'],
      'inst_amt': data['inst_amt'],
      'bal_date': data['bal_date'],
      'due_amt': data['due_amt'],
      'maturity_date': data['maturity_date'],
      'pb_check_date': data['pb_check_date'],
      'closed_status': data['closed_status'] == true ? 1 : 0,
      'status': data['status'] == true ? 1 : 0,
      'remarks': data['remarks'],
      'insert_user': data['insert_user'],
      'insert_date': data['insert_date'],
      'edit_user': data['edit_user'],
      'edit_date': data['edit_date'],
      'input_amount': null,
      'col_remarks': null,
      'col_date_time': null,
      'col_location': null,
      'is_inserted': false,
      'col_group_id': null,
    };
  }

  Future<void> upsertCustomerAccount(Map<String, dynamic> data,
      {bool isReplace = false}) async {
    final db = await DatabaseService().database;
    await db.insert(
      tableName,
      _rowFromApi(data),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCustomerAccountNew(Map<String, dynamic> data,
      {bool isReplace = false}) async {
    final db = await DatabaseService().database;
    await db.insert(
      tableName,
      _rowFromApi(data),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bulk-insert/replace many rows from the API response in a single
  /// transaction instead of one INSERT round-trip per row. For 33k+ rows
  /// this is the difference between a multi-second/minute sync and one
  /// that finishes in well under a second.
  ///
  /// Splits into chunks so a single batch doesn't get too large for the
  /// platform channel.
  Future<void> bulkUpsertAccounts(
    List<Map<String, dynamic>> rows, {
    int chunkSize = 500,
  }) async {
    final db = await DatabaseService().database;

    for (var start = 0; start < rows.length; start += chunkSize) {
      final end =
          (start + chunkSize < rows.length) ? start + chunkSize : rows.length;
      final chunk = rows.sublist(start, end);

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final data in chunk) {
          batch.insert(
            tableName,
            _rowFromApi(data),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    }
  }

  Future<void> deleteAllAccounts() async {
    final db = await DatabaseService().database;
    await db.delete('cd_accounts');
  }

  Future<void> insertIfNotExists(Map<String, dynamic> data) async {
    final db = await DatabaseService().database;
    final existingRecords = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
    if (existingRecords.isEmpty) {
      await db.insert(tableName, _rowFromApi(data));
    }
  }

  /// Bulk equivalent of insertIfNotExists — uses INSERT OR IGNORE so rows
  /// with an existing primary key are silently skipped, instead of doing
  /// one SELECT + one INSERT per row (2 x 33,530 round-trips). Batched in
  /// chunked transactions like bulkUpsertAccounts.
  Future<void> bulkInsertIfNotExists(
    List<Map<String, dynamic>> rows, {
    int chunkSize = 500,
  }) async {
    final db = await DatabaseService().database;

    for (var start = 0; start < rows.length; start += chunkSize) {
      final end =
          (start + chunkSize < rows.length) ? start + chunkSize : rows.length;
      final chunk = rows.sublist(start, end);

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final data in chunk) {
          batch.insert(
            tableName,
            _rowFromApi(data),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
      });
    }
  }

  Future<void> updateInputValuesForNewEntry(String accountId, double amount,
      String remarks, String coordinates, String uid) async {
    final db = await DatabaseService().database;
    DateTime currentDate = DateTime.now();
    String formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(currentDate);

    Map<String, dynamic> originalAccount = await getUserById(
      db: db,
      tableName: tableName,
      userId: accountId,
    );
    Map<String, dynamic> newAccount = Map.from(originalAccount);
    newAccount['id'] = const Uuid().v4();
    newAccount['ac_name'] =
        "${newAccount['ac_name']} (${uid.toString().substring(0, 4)})";
    newAccount['input_amount'] = amount;
    newAccount['col_remarks'] = remarks;
    newAccount['col_date_time'] = formattedDate;
    newAccount['col_location'] = coordinates;
    newAccount['is_inserted'] = true;
    newAccount['col_group_id'] = uid;

    await db.insert(tableName, newAccount);
  }

  Future<Map<String, dynamic>> getUserById({
    required Database db,
    required String tableName,
    required String userId,
  }) async {
    final List<Map<String, dynamic>> result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) {
      throw Exception('User with id $userId not found');
    }
    return result.first;
  }

  /// Kept for compatibility, but prefer the SQL-side helpers below
  /// (getAllActiveAccounts / searchAccounts / getGroupSummaries) for large
  /// datasets — pulling every row into Dart and grouping/filtering there
  /// is the main cause of jank at 30k+ rows.
  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await DatabaseService().database;
    return await db.query(tableName);
  }

  /// Same as getAllAccounts but filters out already-inserted rows in SQL
  /// instead of in the Dart grouping loop.
  Future<List<Map<String, dynamic>>> getAllActiveAccounts() async {
    final db = await DatabaseService().database;
    return await db.query(
      tableName,
      where: 'is_inserted = 0 OR is_inserted IS NULL',
    );
  }

  /// Server-side search. Uses the FTS5 index (fast, handles substring
  /// matches on any column indexed above) when available, otherwise falls
  /// back to a plain LIKE search — e.g. on devices whose SQLite build has
  /// no FTS5 module ("no such module: fts5"), or on an old DB that hasn't
  /// run createTable's FTS setup yet.
  Future<List<Map<String, dynamic>>> searchAccounts(String query) async {
    final db = await DatabaseService().database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getAllActiveAccounts();
    }

    final like = '%$trimmed%';
    Future<List<Map<String, dynamic>>> likeSearch() => db.query(
          tableName,
          where: '(is_inserted = 0 OR is_inserted IS NULL) AND '
              '(ac_name LIKE ? OR id_no LIKE ? OR ac_no LIKE ? OR mf_grp_name LIKE ? OR center_name LIKE ?)',
          whereArgs: [like, like, like, like, like],
        );

    // Already know this device has no FTS5 module — skip straight to
    // LIKE instead of hitting the same error on every keystroke.
    if (!_ftsAvailable) {
      return likeSearch();
    }

    try {
      final ftsQuery = '${trimmed.replaceAll('"', '""')}*';
      return await db.rawQuery('''
        SELECT cd_accounts.* FROM cd_accounts
        JOIN cd_accounts_fts ON cd_accounts.rowid = cd_accounts_fts.rowid
        WHERE cd_accounts_fts MATCH ?
          AND (cd_accounts.is_inserted = 0 OR cd_accounts.is_inserted IS NULL)
      ''', [ftsQuery]);
    } catch (_) {
      // FTS query failed (e.g. module missing after all, or FTS table
      // out of sync) — remember that and fall back to LIKE from now on.
      _ftsAvailable = false;
      return likeSearch();
    }
  }

  /// Group counts computed by SQLite instead of iterating all rows in Dart.
  Future<List<Map<String, dynamic>>> getGroupSummaries() async {
    final db = await DatabaseService().database;
    return db.rawQuery('''
      SELECT mf_grp_name, COUNT(*) as cnt
      FROM cd_accounts
      WHERE is_inserted = 0 OR is_inserted IS NULL
      GROUP BY mf_grp_name
    ''');
  }

  Future<List<Map<String, dynamic>>> CheckIfInserted() async {
    final db = await DatabaseService().database;
    return await db.query(
      tableName,
      where: 'is_inserted = ?',
      whereArgs: [1],
    );
  }

  Future<List<Map<String, dynamic>>> getAccountsByName(String name) async {
    final db = await DatabaseService().database;
    return await db.query(
      tableName,
      where: 'ac_name = ?',
      whereArgs: [name],
    );
  }

  Future<List<Map<String, dynamic>>> getAccountsByAcNo(String acNo) async {
    final db = await DatabaseService().database;
    return await db.query(
      tableName,
      where: 'ac_no = ?',
      whereArgs: [acNo],
    );
  }

  Future<Map<String, dynamic>?> getAccountById(String id) async {
    final db = await DatabaseService().database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAccountsPaginated({
    required int offset,
    required int limit,
  }) async {
    final db = await DatabaseService().database;
    return await db.query(
      tableName,
      where: 'is_inserted = 0 OR is_inserted IS NULL',
      limit: limit,
      offset: offset,
    );
  }

  /// Returns a page of DISTINCT group keys (id_no or mf_grp_name),
  /// ordered so pages are stable and never repeat/skip a key.
  Future<List<String>> getGroupKeysPaginated({
    required String groupColumn, // 'id_no' or 'mf_grp_name'
    required int offset,
    required int limit,
  }) async {
    final db = await DatabaseService().database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT $groupColumn AS key
      FROM $tableName
      WHERE (is_inserted = 0 OR is_inserted IS NULL) AND $groupColumn IS NOT NULL
      ORDER BY $groupColumn
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
    return rows.map((r) => r['key'] as String).toList();
  }

  /// Fetches every row belonging to the given group keys — used right
  /// after getGroupKeysPaginated so a full group's rows are always
  /// loaded together, never split across two pages.
  Future<List<Map<String, dynamic>>> getAccountsForGroupKeys({
    required String groupColumn,
    required List<String> keys,
  }) async {
    if (keys.isEmpty) return [];
    final db = await DatabaseService().database;
    final placeholders = List.filled(keys.length, '?').join(',');
    return db.rawQuery('''
      SELECT * FROM $tableName
      WHERE (is_inserted = 0 OR is_inserted IS NULL)
        AND $groupColumn IN ($placeholders)
    ''', keys);
  }

  Future<int> getGroupKeyCount(String groupColumn) async {
    final db = await DatabaseService().database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT $groupColumn) as count FROM $tableName
      WHERE (is_inserted = 0 OR is_inserted IS NULL) AND $groupColumn IS NOT NULL
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getAccountsCount() async {
    final db = await DatabaseService().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE is_inserted = 0 OR is_inserted IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Combined optional-field search: branch code / account name / account
  /// number. Any field left null or empty is skipped — only the provided
  /// fields are AND'ed together in the WHERE clause. If nothing is
  /// provided, falls back to the normal active-accounts list.
  Future<List<Map<String, dynamic>>> searchAccountsAdvanced({
    String? branch,
    String? name,
    String? accountNumber,
    String? idNo,
    String? mobileNo,
  }) async {
    final db = await DatabaseService().database;

    final conditions = <String>['(is_inserted = 0 OR is_inserted IS NULL)'];
    final args = <Object?>[];

    final trimmedBranch = branch?.trim() ?? '';
    final trimmedName = name?.trim() ?? '';
    final trimmedAccNo = accountNumber?.trim() ?? '';
    final trimmedIdNo = idNo?.trim() ?? '';
    final trimmedMobilNo = mobileNo?.trim() ?? '';

    if (trimmedBranch.isNotEmpty) {
      conditions.add('br_alias LIKE ?');
      args.add('%$trimmedBranch%');
    }
    if (trimmedName.isNotEmpty) {
      conditions.add('ac_name LIKE ?');
      args.add('%$trimmedName%');
    }
    if (trimmedAccNo.isNotEmpty) {
      conditions.add('ac_no LIKE ?');
      args.add('%$trimmedAccNo%');
    }
    if (trimmedIdNo.isNotEmpty) {
      conditions.add('id_no LIKE ?');
      args.add('%$trimmedIdNo%');
    }
    if (trimmedMobilNo.isNotEmpty) {
      conditions.add('contact LIKE ?');
      args.add('%$trimmedMobilNo%');
    }

    // Nothing entered at all — just show the normal active list.
    if (args.isEmpty) {
      return getAllActiveAccounts();
    }

    return db.query(
      tableName,
      where: conditions.join(' AND '),
      whereArgs: args,
    );
  }
}
// import 'package:collector_app/feature/database/database_service.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:intl/intl.dart';
// import 'package:uuid/uuid.dart';

// class CBDB {
//   final tableName = 'cd_accounts';
//   final repeatAccounts = 're-collected';

//   Future<void> createTable(Database database) async {
//     await database.execute("""
//  CREATE TABLE IF NOT EXISTS $tableName(
//   total_record INT NULL,
//     row_no INT NULL,
//     id UUID PRIMARY KEY,
//     client_id INT NULL,
//     common_ac BOOLEAN NULL,
//     br_id INT NULL,
//     br_alias VARCHAR(10) NULL,
//     center_id INT NULL,
//     center_name VARCHAR(255) NULL,
//     mf_grp_id INT NULL,
//     mf_grp_name VARCHAR(255) NULL,
//     iden_id INT NULL,
//     id_no VARCHAR(50) NULL,
//     account_id INT NULL,
//     ac_no VARCHAR(50) NULL,
//     ac_name VARCHAR(255) NULL,
//     p_address TEXT NULL,
//     t_address TEXT NULL,
//     add_location VARCHAR(255) NULL,
//     contact VARCHAR(50) NULL,
//     account_type_id INT NULL,
//     account_type_name VARCHAR(100) NULL,
//     field_officer_id INT NULL,
//     field_officer_name VARCHAR(100) NULL,
//     ac_open_date DATE NULL,
//     return_type_id INT NULL,
//     return_type VARCHAR(50) NULL,
//     rate_of_return DECIMAL(10,2) NULL,
//     post_freq INT NULL,
//     col_amt DECIMAL(10,2) NULL,
//     balance DECIMAL(15,2) NULL,
//     inst_amt DECIMAL(10,2) NULL,
//     bal_date TEXT NULL,
//     due_amt DECIMAL(10,2) NULL,
//     maturity_date DATE NULL,
//     pb_check_date DATE NULL,
//     closed_status BOOLEAN NULL,
//     status BOOLEAN NULL,
//     remarks TEXT NULL,
//     insert_user INT NULL,
//     insert_date TEXT NULL,
//     edit_user INT NULL,
//     edit_date TEXT NULL,
//     input_amount DECIMAL(15,2) NULL,
//     col_remarks TEXT NULL,
//     col_date_time TEXT NULL,
//     col_location TEXT NULL,
//     is_inserted BOOLEAN NULL,
//     col_group_id TEXT NULL
//  );
//  CREATE INDEX idx_ac_name ON cd_accounts(ac_name);
//  CREATE INDEX idx_iden_id ON cd_accounts(iden_id);
//   CREATE INDEX idx_is_inserted ON $tableName(is_inserted);
//  CREATE INDEX idx_id_no ON $tableName(id_no);
//  CREATE INDEX idx_mf_grp_name ON $tableName(mf_grp_name);
//  CREATE INDEX idx_ac_no ON $tableName(ac_no);
// """);

//     // Optional but recommended: full text search index for fast substring
//     // search instead of a leading-wildcard LIKE '%...%' scan.
//     // Requires SQLite compiled with FTS5 (bundled sqflite builds have it).
//     await database.execute("""
//  CREATE VIRTUAL TABLE IF NOT EXISTS cd_accounts_fts USING fts5(
//    ac_name, id_no, ac_no, mf_grp_name, center_name,
//    content='cd_accounts', content_rowid='rowid'
//  );
// """);

//     // Keep the FTS index in sync automatically.
//     await database.execute("""
//  CREATE TRIGGER IF NOT EXISTS cd_accounts_ai AFTER INSERT ON cd_accounts BEGIN
//    INSERT INTO cd_accounts_fts(rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
//    VALUES (new.rowid, new.ac_name, new.id_no, new.ac_no, new.mf_grp_name, new.center_name);
//  END;
// """);
//     await database.execute("""
//  CREATE TRIGGER IF NOT EXISTS cd_accounts_ad AFTER DELETE ON cd_accounts BEGIN
//    INSERT INTO cd_accounts_fts(cd_accounts_fts, rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
//    VALUES('delete', old.rowid, old.ac_name, old.id_no, old.ac_no, old.mf_grp_name, old.center_name);
//  END;
// """);
//     await database.execute("""
//  CREATE TRIGGER IF NOT EXISTS cd_accounts_au AFTER UPDATE ON cd_accounts BEGIN
//    INSERT INTO cd_accounts_fts(cd_accounts_fts, rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
//    VALUES('delete', old.rowid, old.ac_name, old.id_no, old.ac_no, old.mf_grp_name, old.center_name);
//    INSERT INTO cd_accounts_fts(rowid, ac_name, id_no, ac_no, mf_grp_name, center_name)
//    VALUES (new.rowid, new.ac_name, new.id_no, new.ac_no, new.mf_grp_name, new.center_name);
//  END;
// """);
//   }

//   Map<String, dynamic> _rowFromApi(Map<String, dynamic> data) {
//     return {
//       'total_record': data['total_record'],
//       'row_no': data['row_no'],
//       'id': data['id'],
//       'client_id': data['client_id'],
//       'common_ac': data['common_ac'] == true ? 1 : 0,
//       'br_id': data['br_id'],
//       'br_alias': data['br_alias'],
//       'center_id': data['center_id'],
//       'center_name': data['center_name'],
//       'mf_grp_id': data['mf_grp_id'],
//       'mf_grp_name': data['mf_grp_name'],
//       'iden_id': data['iden_id'],
//       'id_no': data['id_no'],
//       'account_id': data['account_id'],
//       'ac_no': data['ac_no'],
//       'ac_name': data['ac_name'],
//       'p_address': data['p_address'],
//       't_address': data['t_address'],
//       'add_location': data['add_location'],
//       'contact': data['contact'],
//       'account_type_id': data['account_type_id'],
//       'account_type_name': data['account_type_name'],
//       'field_officer_id': data['field_officer_id'],
//       'field_officer_name': data['field_officer_name'],
//       'ac_open_date': data['ac_open_date'],
//       'return_type_id': data['return_type_id'],
//       'return_type': data['return_type'],
//       'rate_of_return': data['rate_of_return'],
//       'post_freq': data['post_freq'],
//       'col_amt': data['col_amt'],
//       'balance': data['balance'],
//       'inst_amt': data['inst_amt'],
//       'bal_date': data['bal_date'],
//       'due_amt': data['due_amt'],
//       'maturity_date': data['maturity_date'],
//       'pb_check_date': data['pb_check_date'],
//       'closed_status': data['closed_status'] == true ? 1 : 0,
//       'status': data['status'] == true ? 1 : 0,
//       'remarks': data['remarks'],
//       'insert_user': data['insert_user'],
//       'insert_date': data['insert_date'],
//       'edit_user': data['edit_user'],
//       'edit_date': data['edit_date'],
//       'input_amount': null,
//       'col_remarks': null,
//       'col_date_time': null,
//       'col_location': null,
//       'is_inserted': false,
//       'col_group_id': null,
//     };
//   }

//   Future<void> upsertCustomerAccount(Map<String, dynamic> data,
//       {bool isReplace = false}) async {
//     final db = await DatabaseService().database;
//     await db.insert(
//       tableName,
//       _rowFromApi(data),
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   Future<void> upsertCustomerAccountNew(Map<String, dynamic> data,
//       {bool isReplace = false}) async {
//     final db = await DatabaseService().database;
//     await db.insert(
//       tableName,
//       _rowFromApi(data),
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   /// Bulk-insert/replace many rows from the API response in a single
//   /// transaction instead of one INSERT round-trip per row. For 33k+ rows
//   /// this is the difference between a multi-second/minute sync and one
//   /// that finishes in well under a second.
//   ///
//   /// Splits into chunks so a single batch doesn't get too large for the
//   /// platform channel.
//   Future<void> bulkUpsertAccounts(
//     List<Map<String, dynamic>> rows, {
//     int chunkSize = 500,
//   }) async {
//     final db = await DatabaseService().database;

//     for (var start = 0; start < rows.length; start += chunkSize) {
//       final end =
//           (start + chunkSize < rows.length) ? start + chunkSize : rows.length;
//       final chunk = rows.sublist(start, end);

//       await db.transaction((txn) async {
//         final batch = txn.batch();
//         for (final data in chunk) {
//           batch.insert(
//             tableName,
//             _rowFromApi(data),
//             conflictAlgorithm: ConflictAlgorithm.replace,
//           );
//         }
//         await batch.commit(noResult: true);
//       });
//     }
//   }

//   Future<void> deleteAllAccounts() async {
//     final db = await DatabaseService().database;
//     await db.delete('cd_accounts');
//   }

//   Future<void> insertIfNotExists(Map<String, dynamic> data) async {
//     final db = await DatabaseService().database;
//     final existingRecords = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [data['id']],
//     );
//     if (existingRecords.isEmpty) {
//       await db.insert(tableName, _rowFromApi(data));
//     }
//   }

//   /// Bulk equivalent of insertIfNotExists — uses INSERT OR IGNORE so rows
//   /// with an existing primary key are silently skipped, instead of doing
//   /// one SELECT + one INSERT per row (2 x 33,530 round-trips). Batched in
//   /// chunked transactions like bulkUpsertAccounts.
//   Future<void> bulkInsertIfNotExists(
//     List<Map<String, dynamic>> rows, {
//     int chunkSize = 500,
//   }) async {
//     final db = await DatabaseService().database;

//     for (var start = 0; start < rows.length; start += chunkSize) {
//       final end =
//           (start + chunkSize < rows.length) ? start + chunkSize : rows.length;
//       final chunk = rows.sublist(start, end);

//       await db.transaction((txn) async {
//         final batch = txn.batch();
//         for (final data in chunk) {
//           batch.insert(
//             tableName,
//             _rowFromApi(data),
//             conflictAlgorithm: ConflictAlgorithm.ignore,
//           );
//         }
//         await batch.commit(noResult: true);
//       });
//     }
//   }

//   Future<void> updateInputValuesForNewEntry(String accountId, double amount,
//       String remarks, String coordinates, String uid) async {
//     final db = await DatabaseService().database;
//     DateTime currentDate = DateTime.now();
//     String formattedDate =
//         DateFormat('yyyy-MM-dd HH:mm:ss').format(currentDate);

//     Map<String, dynamic> originalAccount = await getUserById(
//       db: db,
//       tableName: tableName,
//       userId: accountId,
//     );
//     Map<String, dynamic> newAccount = Map.from(originalAccount);
//     newAccount['id'] = const Uuid().v4();
//     newAccount['ac_name'] =
//         "${newAccount['ac_name']} (${uid.toString().substring(0, 4)})";
//     newAccount['input_amount'] = amount;
//     newAccount['col_remarks'] = remarks;
//     newAccount['col_date_time'] = formattedDate;
//     newAccount['col_location'] = coordinates;
//     newAccount['is_inserted'] = true;
//     newAccount['col_group_id'] = uid;

//     await db.insert(tableName, newAccount);
//   }

//   Future<Map<String, dynamic>> getUserById({
//     required Database db,
//     required String tableName,
//     required String userId,
//   }) async {
//     final List<Map<String, dynamic>> result = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [userId],
//     );
//     if (result.isEmpty) {
//       throw Exception('User with id $userId not found');
//     }
//     return result.first;
//   }

//   /// Kept for compatibility, but prefer the SQL-side helpers below
//   /// (getAllActiveAccounts / searchAccounts / getGroupSummaries) for large
//   /// datasets — pulling every row into Dart and grouping/filtering there
//   /// is the main cause of jank at 30k+ rows.
//   Future<List<Map<String, dynamic>>> getAllAccounts() async {
//     final db = await DatabaseService().database;
//     return await db.query(tableName);
//   }

//   /// Same as getAllAccounts but filters out already-inserted rows in SQL
//   /// instead of in the Dart grouping loop.
//   Future<List<Map<String, dynamic>>> getAllActiveAccounts() async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'is_inserted = 0 OR is_inserted IS NULL',
//     );
//   }

//   /// Server-side search. Uses the FTS5 index (fast, handles substring
//   /// matches on any column indexed above) with a fallback to LIKE if the
//   /// FTS table isn't available for some reason (e.g. upgrading an old DB
//   /// without running createTable's new statements).
//   Future<List<Map<String, dynamic>>> searchAccounts(String query) async {
//     final db = await DatabaseService().database;
//     final trimmed = query.trim();
//     if (trimmed.isEmpty) {
//       return getAllActiveAccounts();
//     }

//     try {
//       final ftsQuery = '${trimmed.replaceAll('"', '""')}*';
//       return await db.rawQuery('''
//         SELECT cd_accounts.* FROM cd_accounts
//         JOIN cd_accounts_fts ON cd_accounts.rowid = cd_accounts_fts.rowid
//         WHERE cd_accounts_fts MATCH ?
//           AND (cd_accounts.is_inserted = 0 OR cd_accounts.is_inserted IS NULL)
//       ''', [ftsQuery]);
//     } catch (_) {
//       // Fallback: plain LIKE search (slower, but always works).
//       final like = '%$trimmed%';
//       return db.query(
//         tableName,
//         where: '(is_inserted = 0 OR is_inserted IS NULL) AND '
//             '(ac_name LIKE ? OR id_no LIKE ? OR ac_no LIKE ? OR mf_grp_name LIKE ?)',
//         whereArgs: [like, like, like, like],
//       );
//     }
//   }

//   /// Group counts computed by SQLite instead of iterating all rows in Dart.
//   Future<List<Map<String, dynamic>>> getGroupSummaries() async {
//     final db = await DatabaseService().database;
//     return db.rawQuery('''
//       SELECT mf_grp_name, COUNT(*) as cnt
//       FROM cd_accounts
//       WHERE is_inserted = 0 OR is_inserted IS NULL
//       GROUP BY mf_grp_name
//     ''');
//   }

//   Future<List<Map<String, dynamic>>> CheckIfInserted() async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'is_inserted = ?',
//       whereArgs: [1],
//     );
//   }

//   Future<List<Map<String, dynamic>>> getAccountsByName(String name) async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'ac_name = ?',
//       whereArgs: [name],
//     );
//   }

//   Future<Map<String, dynamic>?> getAccountById(String id) async {
//     final db = await DatabaseService().database;
//     final results = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );

//     return results.isNotEmpty ? results.first : null;
//   }

//   Future<List<Map<String, dynamic>>> getAccountsPaginated({
//     required int offset,
//     required int limit,
//   }) async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'is_inserted = 0 OR is_inserted IS NULL',
//       limit: limit,
//       offset: offset,
//     );
//   }

//   Future<int> getAccountsCount() async {
//     final db = await DatabaseService().database;
//     final result = await db.rawQuery(
//       'SELECT COUNT(*) as count FROM $tableName WHERE is_inserted = 0 OR is_inserted IS NULL',
//     );
//     return Sqflite.firstIntValue(result) ?? 0;
//   }
// }

// import 'package:collector_app/feature/database/database_service.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:intl/intl.dart';
// import 'package:uuid/uuid.dart';

// class CBDB {
//   final tableName = 'cd_accounts';
//   final repeatAccounts = 're-collected';

//   Future<void> createTable(Database database) async {
//     await database.execute("""
//  CREATE TABLE IF NOT EXISTS $tableName(
//   total_record INT NULL,
//     row_no INT NULL,
//     id UUID PRIMARY KEY,
//     client_id INT NULL,
//     common_ac BOOLEAN NULL,
//     br_id INT NULL,
//     br_alias VARCHAR(10) NULL,
//     center_id INT NULL,
//     center_name VARCHAR(255) NULL,
//     mf_grp_id INT NULL,
//     mf_grp_name VARCHAR(255) NULL,
//     iden_id INT NULL,
//     id_no VARCHAR(50) NULL,
//     account_id INT NULL,
//     ac_no VARCHAR(50) NULL,
//     ac_name VARCHAR(255) NULL,
//     p_address TEXT NULL,
//     t_address TEXT NULL,
//     add_location VARCHAR(255) NULL,
//     contact VARCHAR(50) NULL,
//     account_type_id INT NULL,
//     account_type_name VARCHAR(100) NULL,
//     field_officer_id INT NULL,
//     field_officer_name VARCHAR(100) NULL,
//     ac_open_date DATE NULL,
//     return_type_id INT NULL,
//     return_type VARCHAR(50) NULL,
//     rate_of_return DECIMAL(10,2) NULL,
//     post_freq INT NULL,
//     col_amt DECIMAL(10,2) NULL,
//     balance DECIMAL(15,2) NULL,
//     inst_amt DECIMAL(10,2) NULL,
//     bal_date TEXT NULL,
//     due_amt DECIMAL(10,2) NULL,
//     maturity_date DATE NULL,
//     pb_check_date DATE NULL,
//     closed_status BOOLEAN NULL,
//     status BOOLEAN NULL,
//     remarks TEXT NULL,
//     insert_user INT NULL,
//     insert_date TEXT NULL,
//     edit_user INT NULL,
//     edit_date TEXT NULL,
//     input_amount DECIMAL(15,2) NULL,
//     col_remarks TEXT NULL,
//     col_date_time TEXT NULL,
//     col_location TEXT NULL,
//     is_inserted BOOLEAN NULL,
//     col_group_id TEXT NULL
//  );
//  CREATE INDEX idx_ac_name ON cd_accounts(ac_name);
//  CREATE INDEX idx_iden_id ON cd_accounts(iden_id);
//   CREATE INDEX idx_is_inserted ON $tableName(is_inserted);
//  CREATE INDEX idx_id_no ON $tableName(id_no);
// """);
//   }

//   Future<void> upsertCustomerAccount(Map<String, dynamic> data,
//       {bool isReplace = false}) async {
//     final db = await DatabaseService().database;
//     await db.insert(
//       tableName,
//       {
//         'total_record': data['total_record'],
//         'row_no': data['row_no'],
//         'id': data['id'],
//         'client_id': data['client_id'],
//         'common_ac': data['common_ac'] ? 1 : 0,
//         'br_id': data['br_id'],
//         'br_alias': data['br_alias'],
//         'center_id': data['center_id'],
//         'center_name': data['center_name'],
//         'mf_grp_id': data['mf_grp_id'],
//         'mf_grp_name': data['mf_grp_name'],
//         'iden_id': data['iden_id'],
//         'id_no': data['id_no'],
//         'account_id': data['account_id'],
//         'ac_no': data['ac_no'],
//         'ac_name': data['ac_name'],
//         'p_address': data['p_address'],
//         't_address': data['t_address'],
//         'add_location': data['add_location'],
//         'contact': data['contact'],
//         'account_type_id': data['account_type_id'],
//         'account_type_name': data['account_type_name'],
//         'field_officer_id': data['field_officer_id'],
//         'field_officer_name': data['field_officer_name'],
//         'ac_open_date': data['ac_open_date'],
//         'return_type_id': data['return_type_id'],
//         'return_type': data['return_type'],
//         'rate_of_return': data['rate_of_return'],
//         'post_freq': data['post_freq'],
//         'col_amt': data['col_amt'],
//         'balance': data['balance'],
//         'inst_amt': data['inst_amt'],
//         'bal_date': data['bal_date'],
//         'due_amt': data['due_amt'],
//         'maturity_date': data['maturity_date'],
//         'pb_check_date': data['pb_check_date'],
//         'closed_status': data['closed_status'] ? 1 : 0,
//         'status': data['status'] ? 1 : 0,
//         'remarks': data['remarks'],
//         'insert_user': data['insert_user'],
//         'insert_date': data['insert_date'],
//         'edit_user': data['edit_user'],
//         'edit_date': data['edit_date'],
//         'input_amount': null,
//         'col_remarks': null,
//         'col_date_time': null,
//         'col_location': null,
//         'is_inserted': false,
//         'col_group_id': null,
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   Future<void> upsertCustomerAccountNew(Map<String, dynamic> data,
//       {bool isReplace = false}) async {
//     final db = await DatabaseService().database;
//     await db.insert(
//       tableName,
//       {
//         'total_record': data['total_record'],
//         'row_no': data['row_no'],
//         'id': data['id'],
//         'client_id': data['client_id'],
//         'common_ac': data['common_ac'] ? 1 : 0,
//         'br_id': data['br_id'],
//         'br_alias': data['br_alias'],
//         'center_id': data['center_id'],
//         'center_name': data['center_name'],
//         'mf_grp_id': data['mf_grp_id'],
//         'mf_grp_name': data['mf_grp_name'],
//         'iden_id': data['iden_id'],
//         'id_no': data['id_no'],
//         'account_id': data['account_id'],
//         'ac_no': data['ac_no'],
//         'ac_name': data['ac_name'],
//         'p_address': data['p_address'],
//         't_address': data['t_address'],
//         'add_location': data['add_location'],
//         'contact': data['contact'],
//         'account_type_id': data['account_type_id'],
//         'account_type_name': data['account_type_name'],
//         'field_officer_id': data['field_officer_id'],
//         'field_officer_name': data['field_officer_name'],
//         'ac_open_date': data['ac_open_date'],
//         'return_type_id': data['return_type_id'],
//         'return_type': data['return_type'],
//         'rate_of_return': data['rate_of_return'],
//         'post_freq': data['post_freq'],
//         'col_amt': data['col_amt'],
//         'balance': data['balance'],
//         'inst_amt': data['inst_amt'],
//         'bal_date': data['bal_date'],
//         'due_amt': data['due_amt'],
//         'maturity_date': data['maturity_date'],
//         'pb_check_date': data['pb_check_date'],
//         'closed_status': data['closed_status'] ? 1 : 0,
//         'status': data['status'] ? 1 : 0,
//         'remarks': data['remarks'],
//         'insert_user': data['insert_user'],
//         'insert_date': data['insert_date'],
//         'edit_user': data['edit_user'],
//         'edit_date': data['edit_date'],
//         'input_amount': null,
//         'col_remarks': null,
//         'col_date_time': null,
//         'col_location': null,
//         'is_inserted': false,
//         'col_group_id': null,
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   Future<void> deleteAllAccounts() async {
//     final db = await DatabaseService().database;
//     await db.delete('cd_accounts');
//   }

//   Future<void> insertIfNotExists(Map<String, dynamic> data) async {
//     final db = await DatabaseService().database;
//     final existingRecords = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [data['id']],
//     );
//     if (existingRecords.isEmpty) {
//       await db.insert(
//         tableName,
//         {
//           'total_record': data['total_record'],
//           'row_no': data['row_no'],
//           'id': data['id'],
//           'client_id': data['client_id'],
//           'common_ac': data['common_ac'] ? 1 : 0,
//           'br_id': data['br_id'],
//           'br_alias': data['br_alias'],
//           'center_id': data['center_id'],
//           'center_name': data['center_name'],
//           'mf_grp_id': data['mf_grp_id'],
//           'mf_grp_name': data['mf_grp_name'],
//           'iden_id': data['iden_id'],
//           'id_no': data['id_no'],
//           'account_id': data['account_id'],
//           'ac_no': data['ac_no'],
//           'ac_name': data['ac_name'],
//           'p_address': data['p_address'],
//           't_address': data['t_address'],
//           'add_location': data['add_location'],
//           'contact': data['contact'],
//           'account_type_id': data['account_type_id'],
//           'account_type_name': data['account_type_name'],
//           'field_officer_id': data['field_officer_id'],
//           'field_officer_name': data['field_officer_name'],
//           'ac_open_date': data['ac_open_date'],
//           'return_type_id': data['return_type_id'],
//           'return_type': data['return_type'],
//           'rate_of_return': data['rate_of_return'],
//           'post_freq': data['post_freq'],
//           'col_amt': data['col_amt'],
//           'balance': data['balance'],
//           'inst_amt': data['inst_amt'],
//           'bal_date': data['bal_date'],
//           'due_amt': data['due_amt'],
//           'maturity_date': data['maturity_date'],
//           'pb_check_date': data['pb_check_date'],
//           'closed_status': data['closed_status'] ? 1 : 0,
//           'status': data['status'] ? 1 : 0,
//           'remarks': data['remarks'],
//           'insert_user': data['insert_user'],
//           'insert_date': data['insert_date'],
//           'edit_user': data['edit_user'],
//           'edit_date': data['edit_date'],
//           'input_amount': null,
//           'col_remarks': null,
//           'col_date_time': null,
//           'col_location': null,
//           'is_inserted': false,
//           'col_group_id': null,
//         },
//       );
//     }
//   }

//   // Future<void> updateInputValues(String accountId, double amount,
//   //     String remarks, String coordinates) async {
//   //   final db = await DatabaseService().database;
//   //   DateTime currentDate = DateTime.now();

//   //   String formattedDate =
//   //       DateFormat('yyyy-MM-dd HH:mm:ss').format(currentDate);
//   //   await db.update(
//   //     tableName,
//   //     {
//   //       'input_amount': amount,
//   //       'col_remarks': remarks,
//   //       'col_date_time': formattedDate.toString(),
//   //       'col_location': coordinates,
//   //     },
//   //     where: 'id = ?',
//   //     whereArgs: [accountId],
//   //   );
//   // }

//   Future<void> updateInputValuesForNewEntry(String accountId, double amount,
//       String remarks, String coordinates, String uid) async {
//     final db = await DatabaseService().database;
//     DateTime currentDate = DateTime.now();
//     String formattedDate =
//         DateFormat('yyyy-MM-dd HH:mm:ss').format(currentDate);

//     Map<String, dynamic> originalAccount = await getUserById(
//       db: db,
//       tableName: tableName,
//       userId: accountId,
//     );
//     Map<String, dynamic> newAccount = Map.from(originalAccount);
//     newAccount['id'] = const Uuid().v4();
//     newAccount['ac_name'] =
//         "${newAccount['ac_name']} (${uid.toString().substring(0, 4)})";
//     newAccount['input_amount'] = amount;
//     newAccount['col_remarks'] = remarks;
//     newAccount['col_date_time'] = formattedDate;
//     newAccount['col_location'] = coordinates;
//     newAccount['is_inserted'] = true;
//     newAccount['col_group_id'] = uid;

//     await db.insert(tableName, newAccount);
//   }

//   Future<Map<String, dynamic>> getUserById({
//     required Database db,
//     required String tableName,
//     required String userId,
//   }) async {
//     final List<Map<String, dynamic>> result = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [userId],
//     );
//     if (result.isEmpty) {
//       throw Exception('User with id $userId not found');
//     }
//     return result.first;
//   }

//   Future<List<Map<String, dynamic>>> getAllAccounts() async {
//     final db = await DatabaseService().database;
//     return await db.query(tableName);
//   }

//   Future<List<Map<String, dynamic>>> CheckIfInserted() async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'is_inserted = ?',
//       whereArgs: [1],
//     );
//   }

//   Future<List<Map<String, dynamic>>> getAccountsByName(String name) async {
//     final db = await DatabaseService().database;
//     return await db.query(
//       tableName,
//       where: 'ac_name = ?',
//       whereArgs: [name],
//     );
//   }

//   Future<Map<String, dynamic>?> getAccountById(String id) async {
//     final db = await DatabaseService().database;
//     final results = await db.query(
//       tableName,
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );

//     return results.isNotEmpty ? results.first : null;
//   }
// //   Future<List<Map<String, dynamic>>> getAccountsPaginated({
// //   required int offset,
// //   required int limit,
// // }) async {
// //   final db = await DatabaseService().database;
// //   return await db.query(
// //     tableName,
// //     limit: limit,
// //     offset: offset,
// //   );
// // }

// // Future<int> getAccountsCount() async {
// //   final db = await DatabaseService().database;
// //   final result =
// //       await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
// //   return Sqflite.firstIntValue(result) ?? 0;
// // }
// }
