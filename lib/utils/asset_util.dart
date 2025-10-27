String assetPathFromPythonPath(String pythonPath) {
  final pathParts = pythonPath.split('/');
  if (pathParts.length >= 2) {
    final pathNumber = pathParts[0].replaceAll('LearningPath', '');
    final fileName = pathParts[1];
    return 'assets/content/LearningPath$pathNumber/$fileName';
  }
  return pythonPath;
}
