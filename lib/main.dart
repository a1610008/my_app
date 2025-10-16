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
      home: const LearningPathScreen(),
    );
  }
}

// 学習パス一覧
final List<String> learningPaths = ['Path 1', 'Path 2', 'Path 3'];

// メイン画面（学習パス一覧表示）
class LearningPathScreen extends StatelessWidget {
  const LearningPathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習パス')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            // モバイル：左一覧 → 中央説明（縦に並べる）
            return Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Container(
                    color: Colors.grey[200],
                    child: ListView.builder(
                      itemCount: learningPaths.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(learningPaths[index]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContentScreen(
                                  pathTitle: learningPaths[index],
                                  fileName:
                                      'assets/content/path${index + 1}.txt',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '左の学習パスから選択してください',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            );
          } else {
            // ワイド：既存の3カラムレイアウト
            return Row(
              children: [
                Container(
                  width: 200,
                  color: Colors.grey[200],
                  child: ListView.builder(
                    itemCount: learningPaths.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(learningPaths[index]),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContentScreen(
                                pathTitle: learningPaths[index],
                                fileName: 'assets/content/path${index + 1}.txt',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '左の学習パスから選択してください',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                Container(width: 200, color: Colors.grey[100]),
              ],
            );
          }
        },
      ),
    );
  }
}

// コンテンツ画面
class ContentScreen extends StatefulWidget {
  final String pathTitle;
  final String fileName;
  final String? previousPath; // 寄り道戻り用

  const ContentScreen({
    super.key,
    required this.pathTitle,
    required this.fileName,
    this.previousPath,
  });

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  String contentText = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final text = await rootBundle.loadString(widget.fileName);
      setState(() {
        contentText = text;
      });
      debugPrint('✅ 読み込み成功: ${widget.fileName}');
    } catch (e) {
      debugPrint('❌ 読み込み失敗: $e');
      setState(() {
        contentText = 'コンテンツの読み込みに失敗しました：${widget.fileName}\n$e';
      });
    }
  }

  // 左の全パス一覧をモーダルで表示
  void _showLeftPaths() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: learningPaths.length,
            itemBuilder: (_, index) {
              return ListTile(
                title: Text(learningPaths[index]),
                onTap: () {
                  Navigator.pop(context); // モーダル閉じる
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentScreen(
                        pathTitle: learningPaths[index],
                        fileName: 'assets/content/path${index + 1}.txt',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // 右の寄り道候補をモーダルで表示
  void _showSidePaths() {
    final sidePaths = learningPaths
        .where((p) => p != widget.pathTitle)
        .toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: sidePaths.length,
            itemBuilder: (_, index) {
              final target = sidePaths[index];
              return ListTile(
                title: Text(target),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context); // モーダル閉じる
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentScreen(
                        pathTitle: target,
                        fileName:
                            'assets/content/path${learningPaths.indexOf(target) + 1}.txt',
                        previousPath: widget.pathTitle,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pathTitle),
        leading: widget.previousPath != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '一覧を開く',
            onPressed: _showLeftPaths,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '寄り道を開く',
            onPressed: _showSidePaths,
          ),
        ],
      ),
      // 中央コンテンツのみ（左右パネルを廃止して中央を広げる）
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            contentText.isEmpty ? '読み込み中...' : contentText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
