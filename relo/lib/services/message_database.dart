import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message.dart';

class MessageDatabase {
  static final MessageDatabase instance = MessageDatabase._init();

  static Database? _database;

  MessageDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const dateTimeType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE messages (
  id $idType,
  content $textType,
  senderId $textType,
  receiverId $textType,
  timestamp $dateTimeType,
  status $textType
)
''');
  }

  Future<Message> create(Message message) async {
    final db = await instance.database;

    final id = await db.insert('messages', message.toJson());
    return message.copyWith(id: id);
  }

  Future<List<Message>> readPendingMessages() async {
    final db = await instance.database;

    final result = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
    );

    return result.map((json) => Message.fromJson(json)).toList();
  }

  Future<int> update(Message message) async {
    final db = await instance.database;

    return db.update(
      'messages',
      message.toJson(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future close() async {
    final db = await _database;

    if (db != null) {
      await db.close();
    }
  }
}
