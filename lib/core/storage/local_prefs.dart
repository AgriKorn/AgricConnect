import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Small local key-value box for non-sensitive app preferences (e.g. theme
/// mode). Auth tokens never go here — see core/storage/secure_storage.dart.
class LocalPrefs {
  LocalPrefs(this._box);

  static const boxName = 'agriconnect_prefs';

  final Box _box;

  static Future<LocalPrefs> open() async {
    final box = await Hive.openBox(boxName);
    return LocalPrefs(box);
  }

  String? getString(String key) => _box.get(key) as String?;

  Future<void> setString(String key, String value) => _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);
}

final localPrefsProvider = Provider<LocalPrefs>((ref) {
  throw UnimplementedError('overridden in main() after Hive.initFlutter()');
});
