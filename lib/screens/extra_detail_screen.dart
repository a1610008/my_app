import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../utils/parse_util.dart';
import '../utils/asset_util.dart';
import '../utils/log_and_bookmark.dart';

class ExtraDetailScreen extends StatefulWidget {
  final String title;
  final String main;
  final String fromPathTitle;
  final String originRouteName;

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

  final Map<String, Map<String, String>> _itemsCacheLocal = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarkState();
    _fetchRelatedByTitle(widget.title);
    recordEvent('navigate', widget.title, widget.fromPathTitle);
  }

  Future<void> _loadBookmarkState() async {
    final bm = await loadBookmarksSet();
    setState(() => isBookmarked = bm.contains(widget.title));
  }

  Future<void> _toggleBookmark() async {
    final bm = await loadBookmarksSet();
    if (isBookmarked) {
      bm.remove(widget.title);
      await saveBookmarksSet(bm);
      await recordEvent('unbookmark', widget.title, widget.fromPathTitle);
    } else {
      bm.add(widget.title);
      await saveBookmarksSet(bm);
      await recordEvent('bookmark', widget.title, widget.fromPathTitle);
    }
    setState(() => isBookmarked = !isBookmarked);
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
        final parts = splitCsvLine(lines[i], 5);
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
        body: jsonEncode({'user_id': 2, 'keyword': title}),
      );
      if (response.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(response.body);
        final List<Map<String, String>> loaded = [];
        await _ensureItemsLoadedLocal();

        for (final s in paths) {
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

          try {
            final assetPath = assetPathFromPythonPath(s);
            final content = await rootBundle.loadString(assetPath);
            loaded.add(parseKeyValue(content));
          } catch (e) {
            debugPrint('⚠️ detail 参照コンテンツ読み込み失敗 ($s): $e');
          }
        }

        setState(() => related = loaded);
      } else {
        debugPrint('⚠️ Python応答エラー (detail): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Python連携エラー (detail): $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void _showRelatedContentsModal() {
    if (related.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('寄り道コンテンツ'),
          content: Text('関連コンテンツは見つかりませんでした。'),
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
                        Navigator.pop(context);
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
    final appBarTitle = '${widget.fromPathTitle}（関連コンテンツ）';
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.popUntil(context, (route) {
              return route.settings.name == widget.originRouteName ||
                  route.isFirst;
            });
          },
        ),
        actions: [
          IconButton(
            icon: isBookmarked
                ? const Icon(Icons.bookmark, color: Colors.yellow)
                : const Icon(Icons.bookmark_border),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _showRelatedContentsModal,
        child: const Icon(Icons.nature),
      ),
    );
  }
}
