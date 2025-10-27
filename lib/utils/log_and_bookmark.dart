import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

Future<Directory> _appDocDir() async =>
    await getApplicationDocumentsDirectory();

Future<File> _interactionLogFile() async {
  final dir = await _appDocDir();
  final f = File('${dir.path}/interaction_log.csv');
  if (!await f.exists()) {
    await f.writeAsString('timestamp,action,title,from\n');
  }
  return f;
}

Future<void> _sendEventToPython(
  String action,
  String itemId,
  String from,
) async {
  try {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/log_event'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': 2,
        'item_id': itemId,
        'action': action,
        'from': from,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      debugPrint('⚠️ Pythonログ送信エラー: ${response.body}');
    } else {
      debugPrint('✅ Pythonイベント送信成功 ($action / $itemId)');
    }
  } catch (e) {
    debugPrint('❌ Python送信失敗: $e');
  }
}

Future<void> recordEvent(
  String action,
  String title, [
  String from = '',
]) async {
  try {
    final file = await _interactionLogFile();
    final safeTitle = title.replaceAll('"', '""');
    final safeFrom = from.replaceAll('"', '""');
    final line =
        '${DateTime.now().toIso8601String()},$action,"$safeTitle","$safeFrom"\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
    await _sendEventToPython(action, title, from);
  } catch (e) {
    debugPrint('❌ ログ記録失敗: $e');
  }
}

Future<File> _bookmarksFile() async {
  final dir = await _appDocDir();
  return File('${dir.path}/bookmarks.json');
}

Future<Set<String>> loadBookmarksSet() async {
  try {
    final f = await _bookmarksFile();
    if (!await f.exists()) return <String>{};
    final s = await f.readAsString();
    final list = jsonDecode(s) as List<dynamic>;
    return list.map((e) => e.toString()).toSet();
  } catch (e) {
    debugPrint('❌ bookmarks 読み込み失敗: $e');
    return <String>{};
  }
}

Future<void> saveBookmarksSet(Set<String> set) async {
  try {
    final f = await _bookmarksFile();
    await f.writeAsString(jsonEncode(set.toList()), flush: true);
  } catch (e) {
    debugPrint('❌ bookmarks 保存失敗: $e');
  }
}
