import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

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
    _titlesFuture = _loadAllPathTitles();
  }

  Future<List<Map<String, String>>> _loadAllPathTitles() async {
    final result = <Map<String, String>>[];
    for (int i = 1; i <= 10; i++) {
      try {
        final content = await rootBundle.loadString(
          'assets/content/LearningPath$i/PathTitle.txt',
        );
        final parsed = _parseKeyValue(content);
        result.add({
          'path': i.toString(),
          'title': parsed['title'] ?? 'No Title',
          'type': parsed['type'] ?? 'ジャンル不明',
        });
      } catch (e) {
        result.add({
          'path': i.toString(),
          'title': 'タイトル取得失敗',
          'type': 'ジャンル不明',
        });
      }
    }
    return result;
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LearningPathScreen(
                        pathNumber: pathNumber,
                        stepNumber: 1,
                        pathTitle: title,
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
/// 📄 学習パス画面（寄り道ボタン式）
/// =================================
class LearningPathScreen extends StatefulWidget {
  final int pathNumber;
  final int stepNumber;
  final String pathTitle;

  const LearningPathScreen({
    super.key,
    required this.pathNumber,
    required this.stepNumber,
    required this.pathTitle,
  });

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  String mainTitle = '';
  String mainContent = '';

  @override
  void initState() {
    super.initState();
    _loadMainContent();
  }

  Future<void> _loadMainContent() async {
    try {
      final file =
          'assets/content/LearningPath${widget.pathNumber}/Path${widget.pathNumber}-${widget.stepNumber}.txt';
      final content = await rootBundle.loadString(file);
      final parsed = _parseKeyValue(content);
      setState(() {
        mainTitle = parsed['title'] ?? '';
        mainContent = parsed['main'] ?? '';
      });
    } catch (e) {
      debugPrint('❌ メインコンテンツ読み込み失敗: $e');
    }
  }

  Future<List<Map<String, String>>> _loadExtraContents() async {
    final extras = <Map<String, String>>[];
    for (int i = 1; i <= 3; i++) {
      final path =
          'assets/content/ExtraContents/Extra${widget.pathNumber}-${widget.stepNumber}-$i.txt';
      try {
        final content = await rootBundle.loadString(path);
        extras.add(_parseKeyValue(content));
      } catch (_) {
        // ファイルがない場合はスキップ
      }
    }
    return extras;
  }

  void _showExtraContentsPopup() async {
    final extras = await _loadExtraContents();
    if (extras.isEmpty) {
      // 何もないときはメッセージ
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('寄り道コンテンツ'),
          content: const Text('このステップには寄り道コンテンツはありません。'),
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
                color: Colors.blue,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '🌿 寄り道コンテンツ',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: extras.length,
                  itemBuilder: (context, index) {
                    final extra = extras[index];
                    return ListTile(
                      title: Text(extra['title'] ?? ''),
                      subtitle: Text(
                        extra['main'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context); // 一旦ポップアップ閉じる
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
            // 📘 メインタイトル
            Text(
              mainTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 📝 本文
            Expanded(
              child: SingleChildScrollView(
                child: Text(mainContent, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),

            // 🧭 ボタン行
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
                  child: const Text('🌿 寄り道コンテンツ'),
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
/// 🧰 Key:Value パース
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
