import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';

class GameStorage {
  static Future<void> _writes = Future<void>.value();

  @visibleForTesting
  static void resetForTesting() {
    _writes = Future<void>.value();
  }

  static Future<void> _write(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.catchError((Object _) {});
    return result;
  }

  static Future<void> save(Map<String, dynamic> game) {
    final encoded = jsonEncode(game);
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('saved_game', encoded)) {
        throw StateError('Could not save game');
      }
    });
  }

  static Future<Map<String, dynamic>?> load() async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('saved_game');
    if (encoded == null) return null;
    try {
      final game = jsonDecode(encoded) as Map<String, dynamic>;
      if (!_valid(game)) return null;
      return game;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static bool _valid(Map<String, dynamic> game) {
    bool index(dynamic value, int length) => value is int && value >= 0 && value < length;
    if (game['version'] != 1 || game['vsBot'] is! bool ||
        !index(game['variant'], FanoronaVariant.values.length) ||
        !index(game['difficulty'], BotDifficulty.values.length) ||
        !index(game['theme'], GameThemeId.values.length) ||
        ![0, 1, 3, 5, 10].contains(game['minutes']) || game['history'] is! List) {
      return false;
    }
    final variant = FanoronaVariant.values[game['variant'] as int];
    bool point(dynamic p, {bool direction = false}) => p is List && p.length == 2 &&
        p[0] is int && p[1] is int && (direction
          ? p[0].abs() <= 1 && p[1].abs() <= 1 && (p[0] != 0 || p[1] != 0)
          : p[0] >= 0 && p[0] < variant.cols && p[1] >= 0 && p[1] < variant.rows);
    bool state(dynamic s) => s is Map && s['board'] is List &&
        s['board'].length == variant.cols * variant.rows &&
        (s['board'] as List).every((p) => index(p, PieceType.values.length)) &&
        (s['turn'] == PieceType.white.index || s['turn'] == PieceType.black.index) &&
        (s['chain'] == null || point(s['chain'])) &&
        (s['direction'] == null || point(s['direction'], direction: true)) &&
        s['visited'] is List && (s['visited'] as List).every((p) => point(p)) &&
        s['whiteTime'] is int && s['whiteTime'] >= 0 &&
        s['blackTime'] is int && s['blackTime'] >= 0;
    return state(game['state']) && (game['history'] as List).every(state);
  }

  static Future<void> clear() => _write(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_game');
  });

  static Future<bool> vibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vibration') ?? true;
  }

  static Future<void> setVibration(bool enabled) => _write(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration', enabled);
  });
}
