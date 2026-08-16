import 'package:collector_app/feature/database/database_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class CBDB {
  final tableName = 'cd_accounts';
  final repeatAccounts = 're-collected';

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
""");
  }

  Future<void> upsertCustomerAccount(Map<String, dynamic> data,
      {bool isReplace = false}) async {
    final db = await DatabaseService().database;
    await db.insert(
      tableName,
      {
        'total_record': data['total_record'],
        'row_no': data['row_no'],
        'id': data['id'],
        'client_id': data['client_id'],
        'common_ac': data['common_ac'] ? 1 : 0,
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
        'closed_status': data['closed_status'] ? 1 : 0,
        'status': data['status'] ? 1 : 0,
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCustomerAccountNew(Map<String, dynamic> data,
      {bool isReplace = false}) async {
    final db = await DatabaseService().database;
    await db.insert(
      tableName,
      {
        'total_record': data['total_record'],
        'row_no': data['row_no'],
        'id': data['id'],
        'client_id': data['client_id'],
        'common_ac': data['common_ac'] ? 1 : 0,
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
        'closed_status': data['closed_status'] ? 1 : 0,
        'status': data['status'] ? 1 : 0,
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      await db.insert(
        tableName,
        {
          'total_record': data['total_record'],
          'row_no': data['row_no'],
          'id': data['id'],
          'client_id': data['client_id'],
          'common_ac': data['common_ac'] ? 1 : 0,
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
          'closed_status': data['closed_status'] ? 1 : 0,
          'status': data['status'] ? 1 : 0,
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
        },
      );
    }
  }

  // Future<void> updateInputValues(String accountId, double amount,
  //     String remarks, String coordinates) async {
  //   final db = await DatabaseService().database;
  //   DateTime currentDate = DateTime.now();

  //   String formattedDate =
  //       DateFormat('yyyy-MM-dd HH:mm:ss').format(currentDate);
  //   await db.update(
  //     tableName,
  //     {
  //       'input_amount': amount,
  //       'col_remarks': remarks,
  //       'col_date_time': formattedDate.toString(),
  //       'col_location': coordinates,
  //     },
  //     where: 'id = ?',
  //     whereArgs: [accountId],
  //   );
  // }

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

  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await DatabaseService().database;
    return await db.query(tableName);
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
      // orderBy: 'id_no ASC, rowid ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> getAccountsCount() async {
    final db = await DatabaseService().database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
