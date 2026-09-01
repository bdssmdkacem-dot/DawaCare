import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Offline-first local cache.
///
/// `cached_doses` mirrors the fields of `dose_instances` that the Today
/// screen needs to render without a network round-trip.
/// `sync_queue` holds writes made while offline so [SyncEngine] can replay
/// them against Supabase once connectivity returns.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'dawacare_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_doses (
            id TEXT PRIMARY KEY,
            medication_id TEXT NOT NULL,
            schedule_id TEXT NOT NULL,
            patient_id TEXT NOT NULL,
            medication_name TEXT NOT NULL,
            dose_amount TEXT NOT NULL,
            scheduled_at TEXT NOT NULL,
            status TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_cached_doses_patient ON cached_doses (patient_id, scheduled_at)');

        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'PENDING'
          )
        ''');
      },
    );
  }

  // ---- cached_doses -------------------------------------------------------

  Future<void> upsertDoses(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('cached_doses', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDose(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('cached_doses', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> dosesForPatient(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    return db.query(
      'cached_doses',
      where: 'patient_id = ? AND scheduled_at >= ? AND scheduled_at <= ?',
      whereArgs: [patientId, from.toIso8601String(), to.toIso8601String()],
      orderBy: 'scheduled_at ASC',
    );
  }

  // ---- sync_queue -----------------------------------------------------------

  Future<void> enqueue({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payloadJson,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'status': 'PENDING',
    });
  }

  Future<List<Map<String, dynamic>>> pendingSyncOperations() async {
    final db = await database;
    return db.query('sync_queue', where: "status = 'PENDING'", orderBy: 'created_at ASC');
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(String id) async {
    final db = await database;
    await db.rawUpdate('UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }
}
