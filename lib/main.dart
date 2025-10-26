import 'dart:convert';
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

  // CSV 行を指定数のフィールドに分割する（最後のフィールドは残り全部）
  List<String> _splitCsvLine(String line, int fields) {
    final res = <String>[];
    int start = 0;
    for (int i = 0; i < fields - 1; i++) {
      final idx = line.indexOf(',', start);
      if (idx == -1) {
        // 区切りが足りない場合は残りを push して終わり
        res.add(line.substring(start));
        return res;
      }
      res.add(line.substring(start, idx));
      start = idx + 1;
    }
    res.add(line.substring(start)); // 残り全部
    return res;
  }

  /// =================================
  /// 🌿 寄り道コンテンツポップアップ
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
                    return ListTile(
                      title: Text(extra['title'] ?? ''),
                      subtitle: Text(
                        extra['main'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showExtraDetail(extra);
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

  void _showExtraDetail(Map<String, String> extra) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(extra['title'] ?? ''),
        content: SingleChildScrollView(child: Text(extra['main'] ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
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
