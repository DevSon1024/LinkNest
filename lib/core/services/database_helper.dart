import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/link_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _databaseVersion = 6; // Incremented for metadata loading field

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
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        description TEXT,
        imageUrl TEXT,
        createdAt INTEGER NOT NULL,
        domain TEXT NOT NULL,
        tags TEXT DEFAULT "[]",
        notes TEXT,
        status TEXT NOT NULL DEFAULT "pending",
        isFavorite INTEGER NOT NULL DEFAULT 0,
        isMetadataLoaded INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE links ADD COLUMN tags TEXT DEFAULT "[]";');
      await db.execute('ALTER TABLE links ADD COLUMN notes TEXT;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE links ADD COLUMN status TEXT NOT NULL DEFAULT "pending";');
    }
    if (oldVersion < 4) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(links)');
      var columnNames = tableInfo.map((row) => row['name']).toList();
      if (!columnNames.contains('tags')) {
        await db.execute('ALTER TABLE links ADD COLUMN tags TEXT DEFAULT "[]";');
      }
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE links ADD COLUMN isFavorite INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE links ADD COLUMN isMetadataLoaded INTEGER NOT NULL DEFAULT 0');
      // Update existing tags that might be NULL to empty JSON array
      await db.execute('UPDATE links SET tags = "[]" WHERE tags IS NULL OR tags = ""');
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
    print('DatabaseHelper: Inserting link ID: ${link.id}, URL: $normalizedUrl, Tags: ${link.tags}');

    final linkToInsert = link.copyWith(url: normalizedUrl);
    final linkMap = linkToInsert.toMap();

    // Ensure tags is properly serialized
    if (linkMap['tags'] == null || linkMap['tags'] == '') {
      linkMap['tags'] = '[]';
    }

    return await db.insert('links', linkMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LinkModel>> getAllLinks() async {
    final db = await database;
    print('DatabaseHelper: Fetching all links');
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      orderBy: 'createdAt DESC',
    );
    print('DatabaseHelper: Fetched ${maps.length} links');
    return List.generate(maps.length, (i) => LinkModel.fromMap(maps[i]));
  }

  Future<List<LinkModel>> getFavoriteLinks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => LinkModel.fromMap(maps[i]));
  }

  Future<int> updateLink(LinkModel link) async {
    final db = await database;
    print('DatabaseHelper: Updating link ID: ${link.id}, URL: ${link.url}, Notes: "${link.notes}", Tags: ${link.tags}');
    try {
      final linkMap = link.toMap();

      // Do not update the URL, as it's the UNIQUE key.
      linkMap.remove('url');

      // Ensure tags is properly serialized
      if (linkMap['tags'] == null || linkMap['tags'] == '') {
        linkMap['tags'] = '[]';
      }

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

      // Verification
      final verifyResult = await db.query(
        'links',
        where: 'id = ?',
        whereArgs: [link.id],
      );
      if (verifyResult.isNotEmpty) {
        print('DatabaseHelper: Verification - Notes: "${verifyResult.first['notes']}", Tags: "${verifyResult.first['tags']}"');
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

  Future<int> toggleFavoriteStatus(int id, bool isFavorite) async {
    final db = await database;
    return await db.update(
      'links',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('links');
  }
}
