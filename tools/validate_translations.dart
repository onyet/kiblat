// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

final translationsDir = Directory('assets/translations');

RegExp keyRe = RegExp(r'"([^"]+)"\s*:');

void main() async {
  if (!await translationsDir.exists()) {
    print('Translations directory not found: ${translationsDir.path}');
    exit(1);
  }

  final files = translationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  if (files.isEmpty) {
    print('No translation JSON files found.');
    exit(0);
  }

  // Base keys from en.json
  final enFile = files.firstWhere((f) => f.path.endsWith('/en.json'), orElse: () => File(''));
  if (enFile.path.isEmpty) {
    print('Base en.json not found. Please ensure en.json exists in assets/translations.');
  }

  final Map<String, Set<String>> duplicateKeys = {};
  final Map<String, Set<String>> fileKeys = {};
  final Map<String, List<String>> parseErrors = {};

  Map<String, dynamic> enMap = {};
  if (enFile.path.isNotEmpty) {
    try {
      final s = await enFile.readAsString();
      enMap = json.decode(s) as Map<String, dynamic>;
    } catch (e) {
      print('Failed to parse en.json: $e');
      exit(1);
    }
  }

  for (final f in files) {
    final content = await f.readAsString();
    final found = <String>[];
    final duplicates = <String>{};

    final lines = LineSplitter.split(content).toList();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = keyRe.allMatches(line);
      for (final m in matches) {
        final k = m.group(1)!.trim();
        if (found.contains(k)) duplicates.add(k);
        found.add(k);
      }
    }

    fileKeys[f.path] = found.toSet();
    if (duplicates.isNotEmpty) duplicateKeys[f.path] = duplicates;

    // Try to parse JSON to catch syntax errors
    try {
      json.decode(content);
    } catch (e) {
      parseErrors[f.path] = [e.toString()];
    }
  }

  // Compare keys
  final baseKeys = enMap.keys.toSet();

  print('Translation validation report');
  print('==============================\n');

  for (final f in files) {
    final keys = fileKeys[f.path] ?? {};
    final missing = baseKeys.difference(keys);
    final extra = keys.difference(baseKeys);
    print('File: ${f.path}');
    print('  Keys total: ${keys.length}');
    if (missing.isNotEmpty) print('  Missing keys: ${missing.length}');
    if (extra.isNotEmpty) print('  Extra keys: ${extra.length}');
    if (duplicateKeys.containsKey(f.path)) print('  Duplicate keys: ${duplicateKeys[f.path]!.join(', ')}');
    if (parseErrors.containsKey(f.path)) print('  JSON parse error: ${parseErrors[f.path]!.join(', ')}');
    if (missing.isNotEmpty) print('    -> ${missing.toList().join(', ')}');
    if (extra.isNotEmpty) print('    <- ${extra.toList().join(', ')}');

    print('');
  }

  // Summary
  final totalMissing = files.fold<int>(0, (acc, f) => acc + (baseKeys.difference(fileKeys[f.path] ?? {}).length));
  final totalDuplicates = duplicateKeys.values.fold<int>(0, (acc, s) => acc + s.length);
  final filesWithErrors = parseErrors.keys.length;

  print('Summary:');
  print('  Files scanned: ${files.length}');
  print('  Missing keys total: $totalMissing');
  print('  Duplicate keys total: $totalDuplicates');
  print('  Files with JSON parse errors: $filesWithErrors');

  if (totalMissing == 0 && totalDuplicates == 0 && filesWithErrors == 0) {
    print('\nAll translation files look consistent with en.json ✅');
  } else {
    print('\nConsider adding missing keys (use English fallback) and removing duplicates.');
  }
}
