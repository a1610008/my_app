Map<String, String> parseKeyValue(String content) {
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

List<String> splitCsvLine(String line, int fields) {
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
  res.add(line.substring(start));
  return res;
}
