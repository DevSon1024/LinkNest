import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/link_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'links.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
        domain TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertLink(LinkModel link) async {
    final db = await database;
    return await db.insert('links', link.toMap());
  }

  Future<List<LinkModel>> getAllLinks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      orderBy: 'createdAt DESC',
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