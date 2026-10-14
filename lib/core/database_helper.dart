import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jarvis_memory.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> insertLog(String role, String message) async {
    final db = await instance.database;
    await db.insert('logs', {
      'role': role,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final db = await instance.database;
    return await db.query('logs', orderBy: 'id DESC', limit: 100);
  }

  Future<List<Map<String, dynamic>>> searchMemory(String keyword) async {
    final db = await instance.database;
    return await db.query(
      'logs',
      where: 'message LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'id DESC',
      limit: 5,
    );
  }
}
