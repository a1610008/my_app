import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/parse_util.dart';
import 'learning_path_screen.dart';

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
    final list = <Map<String, String>>[];
    for (int i = 1; i <= 10; i++) {
      final path = 'assets/content/LearningPath$i/PathTitle.txt';
      try {
        final content = await rootBundle.loadString(path);
        final parsed = parseKeyValue(content);
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
              final t = titles[index];
              final pathNumber = int.parse(t['path']!);
              final title = t['title']!;
              final type = t['type']!;
              return ListTile(
                title: Text(title),
                subtitle: Text('ジャンル: $type'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: RouteSettings(
                        name: 'learning_path_$pathNumber',
                      ),
                      builder: (_) => LearningPathScreen(
                        pathNumber: pathNumber,
                        stepNumber: 1,
                        pathTitle: title,
                        keyword: '',
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
