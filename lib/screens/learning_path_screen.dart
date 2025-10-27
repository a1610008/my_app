import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'extra_detail_screen.dart';
import '../utils/parse_util.dart';
import '../utils/asset_util.dart';
import '../utils/log_and_bookmark.dart';

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
  String contentKeyword = '';
  List<Map<String, String>> relatedContents = [];

  final Map<String, Map<String, String>> _itemsCache = {};

  @override
  void initState() {
    super.initState();
    contentKeyword = widget.keyword;
    _loadMainContent();
  }

  Future<void> _loadMainContent() async {
    try {
      final file =
          'assets/content/LearningPath${widget.pathNumber}/Path${widget.pathNumber}-${widget.stepNumber}.txt';
      final content = await rootBundle.loadString(file);
      final parsed = parseKeyValue(content);
      final titleToSend = parsed['title'] ?? '';

      setState(() {
        mainTitle = parsed['title'] ?? '';
        mainContent = parsed['main'] ?? '';
        contentKeyword = parsed['keyword'] ?? contentKeyword;
      });

      if (titleToSend.isNotEmpty) {
        await _fetchRelatedContents(titleToSend);
      }
    } catch (e) {
      debugPrint('❌ メインコンテンツ読み込み失敗: $e');
    }
  }

  Future<void> _fetchRelatedContents(String title) async {
    try {
      const userId = 2;
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'keyword': title}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(response.body);
        final List<Map<String, String>> loaded = [];
        await _ensureItemsLoaded();

        for (final s in paths) {
          String? itemId;
          final numericMatch = RegExp(r'^\d+$').firstMatch(s.trim());
          if (numericMatch != null) {
            itemId = s.trim();
          } else {
            final name = s.replaceAll('\\', '/').split('/').last;
            final m = RegExp(r'(\d+)').firstMatch(name);
            if (m != null) itemId = m.group(1);
          }

          if (itemId != null && _itemsCache.containsKey(itemId)) {
            final item = _itemsCache[itemId]!;
            loaded.add({'title': item['title']!, 'main': item['body']!});
          } else {
            try {
              final assetPath = assetPathFromPythonPath(s);
              final content = await rootBundle.loadString(assetPath);
              loaded.add(parseKeyValue(content));
            } catch (e) {
              debugPrint('⚠️ 参照コンテンツ読み込み失敗 ($s): $e');
            }
          }
        }

        setState(() => relatedContents = loaded);
      }
    } catch (e) {
      debugPrint('❌ Python連携エラー: $e');
    }
  }

  Future<void> _ensureItemsLoaded() async {
    if (_itemsCache.isNotEmpty) return;
    try {
      final csv = await rootBundle.loadString('assets/content/items.csv');
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      for (var i = 1; i < lines.length; i++) {
        final parts = splitCsvLine(lines[i], 5);
        if (parts.length >= 3) {
          final id = parts[0].trim();
          _itemsCache[id] = {'title': parts[1].trim(), 'body': parts[2].trim()};
        }
      }
    } catch (e) {
      debugPrint('❌ items.csv 読み込み失敗: $e');
    }
  }

  void _showExtraContentsPopup() {
    if (relatedContents.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('寄り道コンテンツ'),
          content: Text('関連コンテンツはありませんでした。'),
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
                        await recordEvent('click', title, widget.pathTitle);
                        Navigator.pop(context);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pathTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mainTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text(mainContent))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: widget.stepNumber > 1
                      ? () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LearningPathScreen(
                              pathNumber: widget.pathNumber,
                              stepNumber: widget.stepNumber - 1,
                              pathTitle: widget.pathTitle,
                              keyword: widget.keyword,
                            ),
                          ),
                        )
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
                      ? () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LearningPathScreen(
                              pathNumber: widget.pathNumber,
                              stepNumber: widget.stepNumber + 1,
                              pathTitle: widget.pathTitle,
                              keyword: widget.keyword,
                            ),
                          ),
                        )
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
