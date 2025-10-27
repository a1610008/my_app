import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

/// =================================
/// 🌟 ルート
/// =================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learning Path App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LearningPathSelectScreen(),
    );
  }
}

/// =================================
/// 🧭 学習パス選択画面
/// =================================
class LearningPathSelectScreen extends StatefulWidget {
  const LearningPathSelectScreen({super.key});

  @override
  State<LearningPathSelectScreen> createState() =>
      _LearningPathSelectScreenState();
}

class _LearningPathSelectScreenState extends State<LearningPathSelectScreen> {
  late Future<List<Map<String, String>>> _titlesFuture;

  @override
  void initState() {
    super.initState();
    _titlesFuture = _loadTitles();
  }

  Future<List<Map<String, String>>> _loadTitles() async {
    final List<Map<String, String>> list = [];
    // LearningPath1..10 の PathTitle.txt を読み込む
    for (int i = 1; i <= 10; i++) {
      final path = 'assets/content/LearningPath$i/PathTitle.txt';
      try {
        final content = await rootBundle.loadString(path);
        final parsed = _parseKeyValue(content);
        list.add({
          'path': '$i',
          'title': parsed['title'] ?? 'LearningPath$i',
          'type': parsed['type'] ?? '',
        });
      } catch (e) {
        debugPrint('PathTitle 読み込み失敗 ($path): $e');
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習パス一覧')),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _titlesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final titles = snapshot.data!;
          return ListView.builder(
            itemCount: titles.length,
            itemBuilder: (context, index) {
              final pathNumber = int.parse(titles[index]['path']!);
              final title = titles[index]['title']!;
              final type = titles[index]['type']!;
              return ListTile(
                title: Text(title),
                subtitle: Text('ジャンル: $type'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  // 先に PathX-1.txt を読み、keyword を取得してから遷移する
                  String firstKeyword = '';
                  final firstFile =
                      'assets/content/LearningPath$pathNumber/Path$pathNumber-1.txt';
                  try {
                    final firstContent = await rootBundle.loadString(firstFile);
                    final parsedFirst = _parseKeyValue(firstContent);
                    firstKeyword = parsedFirst['keyword'] ?? '';
                  } catch (e) {
                    debugPrint('初回コンテンツ読み込み失敗 ($firstFile): $e');
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: RouteSettings(
                        name: 'learning_path_$pathNumber',
                      ),
                      builder: (context) => LearningPathScreen(
                        pathNumber: pathNumber,
                        stepNumber: 1,
                        pathTitle: title,
                        keyword: firstKeyword,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// =================================
/// 📄 学習パス画面
/// =================================
class LearningPathScreen extends StatefulWidget {
  final int pathNumber;
  final int stepNumber;
  final String pathTitle;
  final String keyword;

  const LearningPathScreen({
    super.key,
    required this.pathNumber,
    required this.stepNumber,
    required this.pathTitle,
    required this.keyword,
  });

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  String mainTitle = '';
  String mainContent = '';
  String contentKeyword = ''; // state側で保持
  List<Map<String, String>> relatedContents = [];

  @override
  void initState() {
    super.initState();
    contentKeyword = widget.keyword; // ナビゲーション時に渡された keyword を初期値に
    _loadMainContent();
    // _fetchRelatedContents は _loadMainContent の中で実行する（そこで最新の keyword を得るため）
  }

  /// =================================
  /// 📥 メインコンテンツ読み込み
  /// =================================
  Future<void> _loadMainContent() async {
    try {
      final file =
          'assets/content/LearningPath${widget.pathNumber}/Path${widget.pathNumber}-${widget.stepNumber}.txt';
      final content = await rootBundle.loadString(file);
      final parsed = _parseKeyValue(content);

      // 送信用タイトルを先に確保
      final titleToSend = parsed['title'] ?? '';

      setState(() {
        mainTitle = parsed['title'] ?? '';
        mainContent = parsed['main'] ?? '';
        contentKeyword =
            parsed['keyword'] ?? contentKeyword; // keyword は内部保持のまま
      });

      // ここで title を送る（以前は keyword を送っていた）
      if (titleToSend.isNotEmpty) {
        debugPrint('📤 送信する title: $titleToSend');
        await _fetchRelatedContents(titleToSend);
      } else {
        debugPrint('⚠️ title が空なのでPython連携をスキップ');
      }
    } catch (e) {
      debugPrint('❌ メインコンテンツ読み込み失敗: $e');
    }
  }

  /// =================================
  /// 🧠 Pythonサーバーへリクエスト
  /// keywordを送り → 関連コンテンツのパスを取得
  /// =================================
  Future<void> _fetchRelatedContents(String title) async {
    try {
      // title をそのまま送る（JSON のキーは既存サーバー側に合わせて 'keyword' のままにしています）
      debugPrint(
        '📤 POST title -> ${Uri.parse('http://10.0.2.2:5000/recommend')} : $title',
      );
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'keyword': title}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(response.body);
        final List<Map<String, String>> loaded = [];

        // items.csv を読み込み（キャッシュ）
        await _ensureItemsLoaded();

        for (final p in paths) {
          final s = p as String;

          // 受け取った値が item_id（数字）の場合は items.csv から取得
          final numericMatch = RegExp(r'^\d+$').firstMatch(s.trim());
          String? itemId;
          if (numericMatch != null) {
            itemId = s.trim();
          } else {
            // パス形式なら末尾ファイル名から数字を抽出 (例: 1.csv や Extra1-1-1.txt など)
            final name = s.replaceAll('\\', '/').split('/').last;
            final m = RegExp(r'(\d+)').firstMatch(name);
            if (m != null) itemId = m.group(1);
          }

          if (itemId != null && _itemsCache.containsKey(itemId)) {
            final item = _itemsCache[itemId]!;
            // CSV 側の body を 'main' キーで保持して UI と整合させる
            loaded.add({
              'title': item['title'] ?? '',
              'main': item['body'] ?? '',
            });
            continue;
          }

          // fallback: これまでどおり asset パスを解決して txt を読む
          try {
            final assetPath = _assetPathFromPythonPath(s);
            final content = await rootBundle.loadString(assetPath);
            loaded.add(_parseKeyValue(content));
          } catch (e) {
            debugPrint('⚠️ 参照コンテンツ読み込み失敗 ($s): $e');
          }
        }

        setState(() {
          relatedContents = loaded;
        });
      } else {
        debugPrint('⚠️ Python側からの応答エラー: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Python連携エラー: $e');
    }
  }

  // items.csv のキャッシュ（item_id -> {title, body}）
  final Map<String, Map<String, String>> _itemsCache = {};

  Future<void> _ensureItemsLoaded() async {
    if (_itemsCache.isNotEmpty) return;
    try {
      final csv = await rootBundle.loadString('assets/content/items.csv');
      final lines = csv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) return;

      // ヘッダを除いてパース
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        // 最初の4区切りで分割（item_id,title,body,tags,category）
        final parts = _splitCsvLine(line, 5);
        if (parts.length < 3) continue;
        final id = parts[0].trim();
        final title = parts[1].trim();
        final body = parts[2].trim();
        _itemsCache[id] = {'title': title, 'body': body};
      }
      debugPrint('✅ items.csv を読み込みました (${_itemsCache.length} 件)');
    } catch (e) {
      debugPrint('❌ items.csv 読み込み失敗: $e');
    }
  }

  /// =================================
  /// 🌿 寄り道コンテンツポップアップ（先頭100字表示、タップで詳細ページへ遷移）
  /// =================================
  void _showExtraContentsPopup() {
    if (relatedContents.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('寄り道コンテンツ'),
          content: const Text('関連コンテンツはありませんでした。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.green,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '🌿 関連コンテンツ',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: relatedContents.length,
                  itemBuilder: (context, index) {
                    final extra = relatedContents[index];
                    final main = extra['main'] ?? '';
                    final preview = main.length > 100
                        ? '${main.substring(0, 100)}…'
                        : main;
                    return ListTile(
                      title: Text(extra['title'] ?? ''),
                      subtitle: Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final title = extra['title'] ?? '';
                        // クリックをログ（自動ブックマークは行わない）
                        await _recordEvent('click', title, widget.pathTitle);

                        Navigator.pop(context); // ダイアログを閉じる
                        // 詳細ページへ遷移（遷移先でブックマーク状態は読み込まれる）
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExtraDetailScreen(
                              title: title,
                              main: extra['main'] ?? '',
                              fromPathTitle: widget.pathTitle,
                              originRouteName:
                                  'learning_path_${widget.pathNumber}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ); // <-- ここを確実に閉じる
  }

  void _showExtraDetail(Map<String, String> extra) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtraDetailScreen(
          title: extra['title'] ?? '',
          main: extra['main'] ?? '',
          fromPathTitle: widget.pathTitle,
          originRouteName: 'learning_path_${widget.pathNumber}',
        ),
      ),
    );
  }

  /// =================================
  /// 🖼️ 画面描画
  /// =================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pathTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mainTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(mainContent, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: widget.stepNumber > 1
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(
                                name: 'learning_path_${widget.pathNumber}',
                              ),
                              builder: (context) => LearningPathScreen(
                                pathNumber: widget.pathNumber,
                                stepNumber: widget.stepNumber - 1,
                                pathTitle: widget.pathTitle,
                                keyword: widget.keyword,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('← 戻る'),
                ),
                ElevatedButton(
                  onPressed: _showExtraContentsPopup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('🌿 関連コンテンツ'),
                ),
                ElevatedButton(
                  onPressed: widget.stepNumber < 3
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              settings: RouteSettings(
                                name: 'learning_path_${widget.pathNumber}',
                              ),
                              builder: (context) => LearningPathScreen(
                                pathNumber: widget.pathNumber,
                                stepNumber: widget.stepNumber + 1,
                                pathTitle: widget.pathTitle,
                                keyword: widget.keyword,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('進む →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =================================
/// 🧰 Key:Value パース関数
/// =================================
Map<String, String> _parseKeyValue(String content) {
  final result = <String, String>{};
  for (final line in content.split('\n')) {
    final parts = line.split(':');
    if (parts.length >= 2) {
      final key = parts[0].trim().toLowerCase();
      final value = parts.sublist(1).join(':').trim();
      result[key] = value;
    }
  }
  return result;
}

// CSV 行を指定数のフィールドに分割する（最後のフィールドは残り全部）
// トップレベルに置くことで複数クラスから使えるようにする
List<String> _splitCsvLine(String line, int fields) {
  final res = <String>[];
  int start = 0;
  for (int i = 0; i < fields - 1; i++) {
    final idx = line.indexOf(',', start);
    if (idx == -1) {
      res.add(line.substring(start));
      return res;
    }
    res.add(line.substring(start, idx));
    start = idx + 1;
  }
  res.add(line.substring(start)); // 残り全部
  return res;
}

String _assetPathFromPythonPath(String pythonPath) {
  // Python側からのパスをアセットパスに変換
  // 例: 'LearningPath1/Path1-1.txt' -> 'assets/content/LearningPath1/Path1-1.txt'
  final pathParts = pythonPath.split('/');
  if (pathParts.length >= 2) {
    final pathNumber = pathParts[0].replaceAll('LearningPath', '');
    final fileName = pathParts[1];
    return 'assets/content/LearningPath$pathNumber/$fileName';
  }
  return pythonPath; // 変換できない場合はそのまま返す
}

/// =================================
/// 📰 個別寄り道コンテンツ画面（全文＋そのページに対する関連コンテンツ）
/// =================================
class ExtraDetailScreen extends StatefulWidget {
  final String title;
  final String main;
  final String fromPathTitle; // 元の学習パスタイトル（表示用）
  final String originRouteName; // 元の学習パスの route name

  const ExtraDetailScreen({
    super.key,
    required this.title,
    required this.main,
    required this.fromPathTitle,
    required this.originRouteName,
  });

  @override
  State<ExtraDetailScreen> createState() => _ExtraDetailScreenState();
}

class _ExtraDetailScreenState extends State<ExtraDetailScreen> {
  List<Map<String, String>> related = [];
  bool loading = false;
  bool isBookmarked = false;

  // 追加：ローカル items.csv キャッシュ（ExtraDetailScreen で参照している）
  final Map<String, Map<String, String>> _itemsCacheLocal = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarkState();
    _fetchRelatedByTitle(widget.title);
    // ナビゲートをログ
    _recordEvent('navigate', widget.title, widget.fromPathTitle);
  }

  Future<void> _loadBookmarkState() async {
    final bm = await _loadBookmarksSet();
    setState(() {
      isBookmarked = bm.contains(widget.title);
    });
  }

  Future<void> _toggleBookmark() async {
    final bm = await _loadBookmarksSet();
    if (isBookmarked) {
      bm.remove(widget.title);
      await _saveBookmarksSet(bm);
      await _recordEvent('unbookmark', widget.title, widget.fromPathTitle);
      setState(() => isBookmarked = false);
    } else {
      bm.add(widget.title);
      await _saveBookmarksSet(bm);
      await _recordEvent('bookmark', widget.title, widget.fromPathTitle);
      setState(() => isBookmarked = true);
    }
  }

  Future<void> _ensureItemsLoadedLocal() async {
    if (_itemsCacheLocal.isNotEmpty) return;
    try {
      final csv = await rootBundle.loadString('assets/content/items.csv');
      final lines = csv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      for (var i = 1; i < lines.length; i++) {
        final parts = _splitCsvLine(lines[i], 5);
        if (parts.length < 3) continue;
        final id = parts[0].trim();
        final title = parts[1].trim();
        final body = parts[2].trim();
        final category = parts.length >= 5 ? parts[4].trim() : '';
        _itemsCacheLocal[id] = {
          'title': title,
          'body': body,
          'category': category,
        };
      }
    } catch (e) {
      debugPrint('❌ items.csv 読み込み失敗 (detail): $e');
    }
  }

  Future<void> _fetchRelatedByTitle(String title) async {
    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'keyword': title}),
      );
      if (response.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(response.body);
        final List<Map<String, String>> loaded = [];
        await _ensureItemsLoadedLocal();

        for (final p in paths) {
          final s = p as String;
          final numericMatch = RegExp(r'^\d+$').firstMatch(s.trim());
          String? itemId;
          if (numericMatch != null) {
            itemId = s.trim();
          } else {
            final name = s.replaceAll('\\', '/').split('/').last;
            final m = RegExp(r'(\d+)').firstMatch(name);
            if (m != null) itemId = m.group(1);
          }

          if (itemId != null && _itemsCacheLocal.containsKey(itemId)) {
            final it = _itemsCacheLocal[itemId]!;
            loaded.add({
              'title': it['title'] ?? '',
              'main': it['body'] ?? '',
              'category': it['category'] ?? '',
            });
            continue;
          }

          // fallback: try load as asset path (convert if necessary)
          try {
            final assetPath = _assetPathFromPythonPath(s);
            final content = await rootBundle.loadString(assetPath);
            loaded.add(_parseKeyValue(content));
          } catch (e) {
            debugPrint('⚠️ detail 参照コンテンツ読み込み失敗 ($s): $e');
          }
        }

        setState(() {
          related = loaded;
        });
      } else {
        debugPrint('⚠️ Python側からの応答エラー (detail): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Python連携エラー (detail): $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // モーダルで関連コンテンツ一覧を表示（_showExtraContentsPopup と同じ Dialog 表示に合わせる）
  void _showRelatedContentsModal() {
    if (related.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('寄り道コンテンツ'),
          content: const Text('関連コンテンツは見つかりませんでした。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.green,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '🌿 関連コンテンツ',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: related.length,
                  itemBuilder: (context, index) {
                    final e = related[index];
                    final preview = (e['main'] ?? '').length > 100
                        ? '${(e['main'] ?? '').substring(0, 100)}…'
                        : (e['main'] ?? '');
                    return ListTile(
                      title: Text(e['title'] ?? ''),
                      subtitle: Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context); // ダイアログを閉じる
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExtraDetailScreen(
                              title: e['title'] ?? '',
                              main: e['main'] ?? '',
                              fromPathTitle: widget.fromPathTitle,
                              originRouteName: widget.originRouteName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AppBar は「元の学習パスのタイトル（関連コンテンツ）」のまま
    final appBarTitle = '${widget.fromPathTitle}（関連コンテンツ）';
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 左上矢印：元の学習パス（originRouteName）まで一気に戻る
            Navigator.popUntil(context, (route) {
              final name = route.settings.name;
              return name == widget.originRouteName || route.isFirst;
            });
          },
        ),
        actions: [
          // ブックマークアイコンを追加
          IconButton(
            icon: isBookmarked
                ? const Icon(Icons.bookmark, color: Colors.yellow)
                : const Icon(Icons.bookmark_border),
            onPressed: () async {
              await _toggleBookmark();
            },
            tooltip: isBookmarked ? 'ブックマークを外す' : 'ブックマークする',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ページタイトル（寄り道ページのタイトル）
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(widget.main, style: const TextStyle(fontSize: 16)),
              ),
            ),
            // ... 下部は既存の UI（関連コンテンツボタン等） ...
          ],
        ),
      ),
    );
  }
}

// --- 追加: ログ＆ブックマーク永続化ユーティリティ ---
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
        'user_id': 2, // ← 追加
        'item_id': itemId,
        'action': action,
        'from': from,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('⚠️ Python側ログ送信エラー: ${response.statusCode} ${response.body}');
    } else {
      debugPrint('✅ Python側へイベント送信成功 ($action / $itemId)');
    }
  } catch (e) {
    debugPrint('❌ Python側イベント送信失敗: $e');
  }
}

Future<void> _recordEvent(
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
    debugPrint('📥 ログ記録: $action - $title');

    // 🔁 Pythonサーバーにも送る
    await _sendEventToPython(action, title, from);
  } catch (e) {
    debugPrint('❌ ログ記録失敗: $e');
  }
}

Future<File> _bookmarksFile() async {
  final dir = await _appDocDir();
  return File('${dir.path}/bookmarks.json');
}

Future<Set<String>> _loadBookmarksSet() async {
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

Future<void> _saveBookmarksSet(Set<String> set) async {
  try {
    final f = await _bookmarksFile();
    await f.writeAsString(jsonEncode(set.toList()), flush: true);
  } catch (e) {
    debugPrint('❌ bookmarks 保存失敗: $e');
  }
}
