import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, namespaced wrapper over [SharedPreferences].
///
/// Used for learner state that must survive restarts (profile, progress cache,
/// offline queue, settings). Content itself is loaded from bundled assets and
/// cached — never duplicated per user.
class LocalStore {
  LocalStore(this._prefs, {this.namespace = 'aa'});

  final SharedPreferences _prefs;
  final String namespace;

  static Future<LocalStore> create({String namespace = 'aa'}) async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs, namespace: namespace);
  }

  String _key(String key) => '$namespace.$key';

  String? getString(String key) => _prefs.getString(_key(key));
  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(_key(key)) ?? fallback;
  int getInt(String key, {int fallback = 0}) =>
      _prefs.getInt(_key(key)) ?? fallback;
  double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(_key(key)) ?? fallback;

  Future<void> setString(String key, String value) =>
      _prefs.setString(_key(key), value);
  Future<void> setBool(String key, bool value) => _prefs.setBool(_key(key), value);
  Future<void> setInt(String key, int value) => _prefs.setInt(_key(key), value);
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);

  /// JSON helpers — prefer these for structured state.
  Object? getJson(String key) {
    final raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Object? value) =>
      _prefs.setString(_key(key), jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(_key(key));

  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('$namespace.'));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
