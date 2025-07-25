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

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final scheme = uri.scheme.toLowerCase() == 'http' ? 'https' : uri.scheme;
      final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
      return Uri(scheme: scheme, host: uri.host.toLowerCase(), path: path, query: uri.query).toString();
    } catch (e) {
      return url.trim().toLowerCase();
    }
  }

  Future<int> insertLink(LinkModel link) async {
    final db = await database;
    final normalizedUrl = _normalizeUrl(link.url);
    print('DatabaseHelper: Inserting link ID: ${link.id}, URL: $normalizedUrl');
    return await db.insert('links', link.toMap()..['url'] = normalizedUrl, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LinkModel>> getAllLinks() async {
    final db = await database;
    print('DatabaseHelper: Fetching all links');
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      orderBy: 'orderIndex ASC, createdAt DESC',
    );
    print('DatabaseHelper: Fetched ${maps.length} links');
    return List.generate(maps.length, (i) => LinkModel.fromMap(maps[i]));
  }

  Future<int> updateLink(LinkModel link) async {
    final db = await database;
    final normalizedUrl = _normalizeUrl(link.url);
    print('DatabaseHelper: Updating link ID: ${link.id}, URL: $normalizedUrl, Notes: "${link.notes}"');
    try {
      final linkMap = link.toMap();
      linkMap['url'] = normalizedUrl;

      // Explicitly handle notes field
      if (link.notes == null) {
        linkMap['notes'] = null;
      }

      print('DatabaseHelper: Link map before update: $linkMap');

      final result = await db.update(
        'links',
        linkMap,
        where: 'id = ?',
        whereArgs: [link.id],
      );
      print('DatabaseHelper: Updated link ID: ${link.id}, Rows affected: $result');

      // Verify the update by fetching the record
      final verifyResult = await db.query(
        'links',
        where: 'id = ?',
        whereArgs: [link.id],
      );
      if (verifyResult.isNotEmpty) {
        print('DatabaseHelper: Verification - Notes field after update: "${verifyResult.first['notes']}"');
      }

      return result;
    } catch (e) {
      print('DatabaseHelper: Error updating link ID: ${link.id}, Error: $e');
      rethrow;
    }
  }

  Future<int> deleteLink(int id) async {
    final db = await database;
    print('DatabaseHelper: Deleting link ID: $id');
    try {
      final result = await db.delete(
        'links',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('DatabaseHelper: Deleted link ID: $id, Rows affected: $result');
      return result;
    } catch (e) {
      print('DatabaseHelper: Error deleting link ID: $id, Error: $e');
      rethrow;
    }
  }

  Future<bool> linkExists(String url) async {
    final db = await database;
    final normalizedUrl = _normalizeUrl(url);
    print('DatabaseHelper: Checking if link exists: $normalizedUrl');
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      where: 'url = ?',
      whereArgs: [normalizedUrl],
      limit: 1,
    );
    print('DatabaseHelper: Link exists: ${maps.isNotEmpty}');
    return maps.isNotEmpty;
  }
}
