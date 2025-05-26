import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/link_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _databaseVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'links.db');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE links(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      imageUrl TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      domain TEXT NOT NULL,
      tags TEXT NOT NULL,
      notes TEXT,
      orderIndex INTEGER
    )
  ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE links ADD COLUMN tags TEXT NOT NULL DEFAULT "[]";');
      await db.execute('ALTER TABLE links ADD COLUMN notes TEXT;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE links ADD COLUMN orderIndex INTEGER;');
    }
  }

  Future<int> insertLink(LinkModel link) async {
    final db = await database;
    return await db.insert('links', link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LinkModel>> getAllLinks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      orderBy: 'orderIndex ASC, createdAt DESC',
    );
    return List.generate(maps.length, (i) {
      return LinkModel.fromMap(maps[i]);
    });
  }

  Future<int> updateLink(LinkModel link) async {
    final db = await database;
    return await db.update(
      'links',
      link.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );
  }

  Future<int> deleteLink(int id) async {
    final db = await database;
    return await db.delete(
      'links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> linkExists(String url) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}