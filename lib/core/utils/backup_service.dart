import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';

/// نسخ احتياطي كامل (كل الجداول + الإعدادات) كملف JSON، واستعادته على هاتف آخر.
class BackupService {
  static const _format = 'makhzani-backup';
  static const _version = 1;

  /// يكتب النسخة في ملف مؤقت ويعيد مساره (للمشاركة).
  static Future<File> export() async {
    final db = await DatabaseHelper.instance.database;
    final tables = <String, dynamic>{};
    for (final t in DatabaseHelper.tables) {
      tables[t] = await db.query(t);
    }
    final settings = await SettingsRepository().load();
    final payload = {
      'format': _format,
      'version': _version,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'settings': settings,
    };
    final dir = await getTemporaryDirectory();
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'makhzani-backup-${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  /// يستبدل كل البيانات الحالية بمحتوى النسخة. يرمي استثناءً إن كان الملف غير صالح.
  static Future<void> restore(String jsonText) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map || decoded['format'] != _format) {
      throw const FormatException('الملف ليس نسخة احتياطية لمخزني');
    }
    final tables = Map<String, dynamic>.from(decoded['tables'] as Map);
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final t in DatabaseHelper.tables) {
        await txn.delete(t); // الأبناء أولاً
      }
      for (final t in DatabaseHelper.tables.reversed) {
        final rows = (tables[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
    final s = Map<String, dynamic>.from((decoded['settings'] as Map?) ?? {});
    await SettingsRepository().save(
      storeName: s['storeName'] as String?,
      phone: s['phone'] as String?,
      address: s['address'] as String?,
      currency: s['currency'] as String?,
      dark: s['dark'] as bool?,
      dollarRate: (s['dollarRate'] as num?)?.toDouble(),
      themeColor: (s['themeColor'] as num?)?.toInt(),
    );
  }
}
