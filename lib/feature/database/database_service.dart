import 'package:collector_app/feature/database/cb_db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DatabaseService {
  Database? _database;
  static const int _dbVersion = 2;
  

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initialize();
    return _database!;
  }

  Future<String> get fullPath async {
    const name = 'cbdata.db';
    final path = await getDatabasesPath();
    return join(path, name);
  }

  Future<Database> _initialize() async {
    final path = await fullPath;
    var database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: create,
      onUpgrade: _upgrade,
      singleInstance: true,
    );
    return database;
  }

  Future<void> create(Database database, int version) async =>
      await CBDB().createTable(database);


  Future<void> _upgrade(Database database, int oldVersion, int newVersion) async{
   if(oldVersion < 2){
     try {
        await database.execute(
          'ALTER TABLE cd_accounts ADD COLUMN pull_session_id TEXT NULL',
        );
      } catch (e) {
        // Column may already exist (e.g. hot-restart during dev re-ran
        // this) — don't let that crash app startup.
        print('Migration to v2 skipped/failed: $e');
      }
   }
  }    
}
