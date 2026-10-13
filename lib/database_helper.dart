
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'models/folder.dart';
import 'models/card_record.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  // Original Activity 08 table — preserve it.
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _db;

  Future<void> init() async {
    final documentsDirectory =
        await getApplicationDocumentsDirectory();
    final databasePath =
        join(documentsDirectory.path, _databaseName);

    _db = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Fresh installations receive both the original and new tables.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');

    await _createCatalogueTables(db);
  }

  // Existing installations keep my_table and its saved records.
  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createCatalogueTables(db);
    }
  }

  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES folders(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cards_folder_id
      ON cards(folder_id)
    ''');
  }

  // Original Activity 08 CRUD methods — retained.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table);
  }

  Future<int> queryRowCount() async {
    final results = await _db.rawQuery(
      'SELECT COUNT(*) FROM $table',
    );

    return Sqflite.firstIntValue(results) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final int id = row[columnId] as int;

    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Database access.
  Future<Database> get database async => _db;

  // ---------- FOLDER OPERATIONS ----------

  Future<int> createFolder(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    return await _db.insert('folders', {
      'name': trimmedName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Folder>> getFolders() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at,
             COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.id
    ''');

    return rows.map((row) => Folder.fromMap(row)).toList();
  }

  Future<int> deleteFolder(int folderId) async {
    return await _db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  // ---------- CARD OPERATIONS ----------

  static const allowedSuits = [
    'Hearts',
    'Diamonds',
    'Clubs',
    'Spades',
  ];

  void _validateCard({
    required String title,
    required String suit,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Card title cannot be empty.');
    }

    if (!allowedSuits.contains(suit)) {
      throw ArgumentError('Choose a valid card suit.');
    }
  }

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'id',
    );

    return rows.map((row) => CardRecord.fromMap(row)).toList();
  }

  Future<int> createCard({
    required String title,
    required String suit,
    required int folderId,
    String notes = '',
    String? imageRef,
  }) async {
    _validateCard(title: title, suit: suit);

    return await _db.insert('cards', {
      'title': title.trim(),
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    });
  }

  Future<int> updateCard({
    required int id,
    required String title,
    required String suit,
    required int folderId,
    String notes = '',
    String? imageRef,
  }) async {
    _validateCard(title: title, suit: suit);

    return await _db.update(
      'cards',
      {
        'title': title.trim(),
        'suit': suit,
        'notes': notes,
        'image_ref': imageRef,
        'folder_id': folderId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCard(int cardId) async {
    return await _db.delete(
      'cards',
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  // ---------- DATABASE DIAGNOSTICS ----------

  Future<void> printDiagnostics() async {
    debugPrint('--- ACTIVITY 09 DATABASE DIAGNOSTICS ---');

    final version = await _db.rawQuery('PRAGMA user_version');
    debugPrint('Database version: $version');

    final foreignKeys = await _db.rawQuery('PRAGMA foreign_keys');
    debugPrint('Foreign keys enabled: $foreignKeys');

    final tables = await _db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ORDER BY name
    ''');
    debugPrint('Tables: $tables');

    final foreignKeyList =
        await _db.rawQuery('PRAGMA foreign_key_list(cards)');
    debugPrint('Cards foreign keys: $foreignKeyList');

    final indexes = await _db.rawQuery('PRAGMA index_list(cards)');
    debugPrint('Card indexes: $indexes');

    final guests = await _db.query(table);
    debugPrint('Original Activity 08 rows: $guests');

    final allCards = await _db.query('cards');
debugPrint('All current cards: $allCards');

final signal = await _db.rawQuery('''
  SELECT id, title, suit, image_ref, folder_id
  FROM cards
  WHERE LOWER(title) = ?
''', ['signal']);
debugPrint('Signal image reference: $signal');

    debugPrint('--- END DIAGNOSTICS ---');
  }
}
