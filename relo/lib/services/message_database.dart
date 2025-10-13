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
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  content $textType,
  senderId $textType,
  conversationId $textType,
  timestamp $textType,
  status $textType,
  avatarUrl $textNullable
)
''');
  }

  Future<Message> create(Message message) async {
    final db = await instance.database;

    await db.insert('messages', {
      'id': message.id,
      'content': message.content,
      'senderId': message.senderId,
      'conversationId': message.conversationId,
      'timestamp': message.timestamp.toIso8601String(),
      'status': message.status,
      'avatarUrl': message.avatarUrl,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return message;
  }

  Future<List<Message>> readPendingMessages() async {
    final db = await instance.database;

    final result = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
    );

    return result.map((json) {
      return Message(
        id: json['id'] as String,
        content: json['content'] as String,
        senderId: json['senderId'] as String,
        conversationId: json['conversationId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: json['status'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
    }).toList();
  }

  Future<int> update(Message message) async {
    final db = await instance.database;

    return db.update(
      'messages',
      {
        'content': message.content,
        'senderId': message.senderId,
        'conversationId': message.conversationId,
        'timestamp': message.timestamp.toIso8601String(),
        'status': message.status,
        'avatarUrl': message.avatarUrl,
      },
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }

  Future<List<Message>> readFailedMessages() async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'timestamp ASC',
    );
    return result.map((json) => Message.fromJson(json)).toList();
  }
}
