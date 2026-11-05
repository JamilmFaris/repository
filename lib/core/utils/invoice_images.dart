import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// أرشفة صور فواتير الموردين الورقية داخل مجلد التطبيق.
/// في قاعدة البيانات يُحفظ اسم الملف فقط (لا المسار الكامل) حتى يبقى صالحاً بعد تغيّر المسار.
class InvoiceImages {
  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'purchase_images'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// يختار صورة من المعرض/الملفات وينسخها لمجلد التطبيق. يعيد اسم الملف أو null عند الإلغاء.
  static Future<String?> pickAndStore() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final name = 'purchase-${DateTime.now().microsecondsSinceEpoch}.$ext';
    final target = File(p.join((await dir()).path, name));
    if (f.bytes != null) {
      await target.writeAsBytes(f.bytes!);
    } else if (f.path != null) {
      await File(f.path!).copy(target.path);
    } else {
      return null;
    }
    return name;
  }

  static Future<File?> resolve(String? name) async {
    if (name == null || name.isEmpty) return null;
    final f = File(p.join((await dir()).path, name));
    return await f.exists() ? f : null;
  }

  static Future<void> delete(String? name) async {
    final f = await resolve(name);
    if (f != null) await f.delete();
  }
}
