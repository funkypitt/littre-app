import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/browse_entry.dart';
import '../models/entry.dart';
import 'term_matching.dart';

/// Service singleton d'accès à la base SQLite du Littré.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'littre.db');

    // Vérifier si la base doit être copiée depuis les assets
    final exists = await databaseExists(dbPath);
    if (!exists) {
      await _copyDatabase(dbPath);
    }

    return openDatabase(dbPath, readOnly: true);
  }

  Future<void> _copyDatabase(String dbPath) async {
    // S'assurer que le répertoire existe
    await Directory(dirname(dbPath)).create(recursive: true);

    // Copier depuis les assets
    final data = await rootBundle.load('assets/littre.db');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(dbPath).writeAsBytes(bytes, flush: true);
  }

  /// Recherche par préfixe (autocomplete) sur terme_normalise.
  Future<List<DictionaryEntry>> searchByPrefix(
    String query, {
    int limit = 20,
  }) async {
    final db = await database;
    final normalized = normalizeTerm(query);
    if (normalized.isEmpty) return [];

    // Le tri des identifiants se fait sur l'index seul, sans lire les articles.
    final results = await db.rawQuery(
      '''SELECT * FROM entries
         WHERE id IN (
           SELECT id FROM entries
           WHERE $foldedColumn LIKE ?
           ORDER BY $foldedColumn
           LIMIT ?)
         ORDER BY $foldedColumn''',
      ['$normalized%', limit],
    );
    return results.map((m) => DictionaryEntry.fromMap(m)).toList();
  }

  /// Recherche plein texte via FTS5.
  Future<List<DictionaryEntry>> searchFullText(
    String query, {
    int limit = 50,
  }) async {
    final db = await database;
    final sanitized = query.replaceAll('"', '').trim();
    if (sanitized.isEmpty) return [];

    final results = await db.rawQuery(
      '''SELECT e.* FROM entries_fts fts
         JOIN entries e ON e.id = fts.rowid
         WHERE entries_fts MATCH ?
         ORDER BY rank
         LIMIT ?''',
      ['"$sanitized"', limit],
    );
    return results.map((m) => DictionaryEntry.fromMap(m)).toList();
  }

  /// Récupère une entrée par ID.
  Future<DictionaryEntry?> getEntry(int id) async {
    final db = await database;
    final results = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return DictionaryEntry.fromMap(results.first);
  }

  /// Récupère l'entrée visée par un renvoi (« retombée », « avoir.1 »,
  /// « abondant » pour ABONDANT, ANTE).
  Future<DictionaryEntry?> getEntryByReference(String ref) async {
    final db = await database;
    final word = normalizeTerm(parseReference(ref).word);
    if (word.isEmpty) return null;

    // Mots-vedettes où le mot figure en entier, dans l'ordre du dictionnaire.
    final candidates = await db.rawQuery(
      '''SELECT id, terme FROM entries
         WHERE id IN (
           SELECT id FROM entries
           WHERE instr(' ' || replace($foldedColumn, ',', ' ,') || ' ', ?) > 0)
         ORDER BY id''',
      [' ${word.replaceAll(',', ' ,')} '],
    );
    final index = resolveReference(
      ref,
      candidates.map((m) => m['terme'] as String).toList(),
    );
    if (index == null) return null;
    return getEntry(candidates[index]['id'] as int);
  }

  /// Liste les termes commençant par une lettre.
  Future<List<DictionaryEntry>> getTermsByLetter(
    String letter, {
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await database;
    final results = await db.query(
      'entries',
      where: 'terme_normalise LIKE ?',
      whereArgs: ['${letter.toLowerCase()}%'],
      orderBy: 'terme_normalise',
      limit: limit,
      offset: offset,
    );
    return results.map((m) => DictionaryEntry.fromMap(m)).toList();
  }

  static const _browseColumns =
      'id, terme, nature, substr(corps, 1, 2500) AS debut, '
      'length(corps) AS longueur';

  /// Les articles qui se suivent dans le dictionnaire à partir de [id].
  Future<List<BrowseEntry>> browseFrom(int id, {int limit = 60}) async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT $_browseColumns FROM entries WHERE id >= ? ORDER BY id LIMIT ?',
      [id, limit],
    );
    return results.map((m) => BrowseEntry.fromMap(m)).toList();
  }

  /// Les articles qui précèdent [id], dans l'ordre du dictionnaire.
  Future<List<BrowseEntry>> browseBefore(int id, {int limit = 60}) async {
    final db = await database;
    final results = await db.rawQuery(
      '''SELECT $_browseColumns FROM entries
         WHERE id < ? ORDER BY id DESC LIMIT ?''',
      [id, limit],
    );
    return results.reversed.map((m) => BrowseEntry.fromMap(m)).toList();
  }

  Map<String, int>? _letterStarts;

  /// Le premier article de chaque lettre (« A » → 1, « B » → 5248…),
  /// dans l'ordre de l'alphabet. Chaque lettre s'ouvre sur son propre article.
  Future<Map<String, int>> getLetterStarts() async {
    if (_letterStarts != null) return _letterStarts!;
    final db = await database;
    final results = await db.rawQuery(
      '''SELECT upper(terme_normalise) AS lettre, min(id) AS debut
         FROM entries
         WHERE length(terme_normalise) = 1
           AND terme_normalise BETWEEN 'a' AND 'z'
         GROUP BY terme_normalise
         ORDER BY debut''',
    );
    _letterStarts = {
      for (final m in results) m['lettre'] as String: m['debut'] as int,
    };
    return _letterStarts!;
  }

  /// Mot aléatoire.
  Future<DictionaryEntry?> getRandomEntry() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT * FROM entries ORDER BY RANDOM() LIMIT 1',
    );
    if (results.isEmpty) return null;
    return DictionaryEntry.fromMap(results.first);
  }

  /// Nombre total d'entrées.
  Future<int> getEntryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM entries');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
