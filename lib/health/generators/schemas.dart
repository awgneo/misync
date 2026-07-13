// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final apkSourcesDir = '.apks/mi_fitness_source';

  // 1. Resolve ReportType constants from SportReportBaseParser.java
  final reportTypeConstants = <String, String>{};
  final baseParserFile = File(
    '$apkSourcesDir/sources/com/xiaomi/fit/fitness/parser/sport/base/SportReportBaseParser.java',
  );
  if (baseParserFile.existsSync()) {
    final content = baseParserFile.readAsStringSync();
    final matches = RegExp(
      r'public\s+static\s+final\s+int\s+(\w+)\s*=\s*(-?\d+);',
    ).allMatches(content);
    for (final m in matches) {
      reportTypeConstants[m.group(1)!] = m.group(2)!;
    }
  } else {
    print('Decompiled base parser file not found: ${baseParserFile.path}');
    exit(1);
  }

  // 2. Resolve DependDataType fields from SportReportBaseParser.java
  final dependDataMap = <String, String>{};
  if (baseParserFile.existsSync()) {
    final content = baseParserFile.readAsStringSync();
    final matches = RegExp(
      r'DependDataType\s+(\w+)\s*=\s*new\s+FitnessDataBaseParser\.DependDataType\((\d+),\s*new\s+Integer\[\]\{([^}]+)\}\);',
    ).allMatches(content);
    for (final m in matches) {
      final fieldName = m.group(1)!;
      final type = m.group(2)!;
      final vals = m.group(3)!.split(',').map((s) => s.trim()).join(', ');
      final getterName =
          'get${fieldName[0].toUpperCase()}${fieldName.substring(1)}()';
      dependDataMap[getterName] = 'DependDataType($type, [$vals])';
    }
  }

  // 3. Resolve Sport-to-Class mappings dynamically from FitnessDataParser.java
  final sportTypeMap = <String, List<int>>{};
  final dataParserFile = File(
    '$apkSourcesDir/sources/com/xiaomi/fit/fitness/parser/FitnessDataParser.java',
  );
  if (dataParserFile.existsSync()) {
    final lines = dataParserFile.readAsLinesSync();
    bool inMethod = false;
    final currentCases = <int>[];

    for (final line in lines) {
      if (line.contains(
        'private final SportReportBaseParser getSportReportParserInstance',
      )) {
        inMethod = true;
        continue;
      }
      if (inMethod && line.contains('private final FitnessBinaryData')) {
        break; // Exited method
      }

      if (inMethod) {
        final caseMatch = RegExp(r'case\s+(\d+):').firstMatch(line);
        if (caseMatch != null) {
          currentCases.add(int.parse(caseMatch.group(1)!));
        }
        final returnMatch = RegExp(
          r'return\s+new\s+(\w+)ReportParser\(\);',
        ).firstMatch(line);
        if (returnMatch != null && currentCases.isNotEmpty) {
          final className = returnMatch.group(1)!;
          final name =
              className.substring(0, 1).toLowerCase() + className.substring(1);
          sportTypeMap[name] = List<int>.from(currentCases);
          currentCases.clear();
        }
      }
    }
  } else {
    print('FitnessDataParser file not found: ${dataParserFile.path}');
    exit(1);
  }

  // 3b. Parse sleep schema dynamically from NightSleepParser.java
  final sleepItems = <String>[];
  final sleepParserFile = File('$apkSourcesDir/sources/com/xiaomi/fit/fitness/parser/daily/NightSleepParser.java');
  if (sleepParserFile.existsSync()) {
    final content = sleepParserFile.readAsStringSync();
    final regex = RegExp(r'reportDataTypeArray\s*=\s*\{([^}]+)\}');
    final match = regex.firstMatch(content);
    if (match != null) {
      final arrayContent = match.group(1)!;
      final itemRegex = RegExp(r'new\s+FitnessDataBaseParser\.OneDimenDataType\(([\s\S]+?)\)(?=\s*(?:,|\}|$))');
      final matches = itemRegex.allMatches(arrayContent);
      for (final m in matches) {
        final argsStr = m.group(1)!;
        final args = argsStr.split(',').map((s) => s.trim()).toList();
        final type = args[0];
        final byteCount = args[1];
        final supportVersion = args[2];
        sleepItems.add('    OneDimenDataType($type, $byteCount, $supportVersion),');
      }
    }
  } else {
    print('NightSleepParser file not found: ${sleepParserFile.path}');
    exit(1);
  }

  // 4. Scan sport report parsers
  final dir = Directory(
    '$apkSourcesDir/sources/com/xiaomi/fit/fitness/parser/sport/report',
  );
  if (!dir.existsSync()) {
    print('Sport report parser directory not found: ${dir.path}');
    exit(1);
  }

  final files = dir.listSync().whereType<File>().toList();
  final result = StringBuffer();

  result.writeln("import 'types/types.dart';");
  result.writeln("export 'types/schema.dart';\n");
  result.writeln('class Schemas {');

  // Keep sleep schema
  result.writeln('  static const sleep = [');
  for (final item in sleepItems) {
    result.writeln(item);
  }
  result.writeln('  ];\n');

  final schemaMap = <String, String>{};

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('ReportParser.java')) continue;

    final content = file.readAsStringSync();
    // Find reportDataTypeArray declaration
    final regex = RegExp(r'reportDataTypeArray\s*=\s*\{([^}]+)\}');
    final match = regex.firstMatch(content);
    if (match == null) continue;

    final arrayContent = match.group(1)!;
    final itemRegex = RegExp(
      r'new\s+FitnessDataBaseParser\.OneDimenDataType\(([\s\S]+?)\)(?=\s*(?:,|\}|$))',
    );
    final matches = itemRegex.allMatches(arrayContent);

    final dartItems = <String>[];
    for (final m in matches) {
      final argsStr = m.group(1)!;
      final args = argsStr.split(',').map((s) => s.trim()).toList();
      if (args.isEmpty) continue;

      var type = args[0];
      if (type.startsWith('SportReportBaseParser.ReportType.')) {
        final key = type.substring('SportReportBaseParser.ReportType.'.length);
        type = reportTypeConstants[key] ?? type;
      }
      if (reportTypeConstants.containsKey(type)) {
        type = reportTypeConstants[type]!;
      }

      final byteCount = args[1];
      final supportVersion = args[2];

      bool isFloat = false;
      String? dependData;
      bool isUnsigned = false;

      if (args.length > 3) {
        final arg3 = args[3];
        if (arg3 == 'true' || arg3 == 'false') {
          isFloat = arg3 == 'true';
          if (args.length > 4) {
            final arg4 = args[4];
            if (arg4 != 'null') {
              dependData = dependDataMap[arg4] ?? arg4;
            }
          }
          if (args.length > 5) {
            isUnsigned = args[5] == 'true';
          }
        } else {
          // arg3 is dependData
          if (arg3 != 'null') {
            dependData = dependDataMap[arg3] ?? arg3;
          }
          if (args.length > 4) {
            isUnsigned = args[4] == 'true';
          }
        }
      }

      // Resolve dependData if it's a ReportType constant reference
      if (dependData != null) {
        if (dependData.startsWith('SportReportBaseParser.ReportType.')) {
          final key = dependData.substring(
            'SportReportBaseParser.ReportType.'.length,
          );
          dependData = reportTypeConstants[key] ?? dependData;
        }
        if (reportTypeConstants.containsKey(dependData)) {
          dependData = reportTypeConstants[dependData]!;
        }
      }

      final optionals = <String>[];
      if (isFloat) optionals.add('isFloat: true');
      if (dependData != null) optionals.add('dependData: $dependData');
      if (isUnsigned) optionals.add('isUnsigned: true');

      final optStr = optionals.isNotEmpty ? ', ${optionals.join(', ')}' : '';
      dartItems.add(
        '    OneDimenDataType($type, $byteCount, $supportVersion$optStr),',
      );
    }

    final baseClean = name.replaceAll('ReportParser.java', '');
    final schemaName =
        '${baseClean.substring(0, 1).toLowerCase()}${baseClean.substring(1)}Exercise';
    schemaMap[schemaName] = baseClean;

    result.writeln('  static const _$schemaName = [');
    for (final item in dartItems) {
      result.writeln(item);
    }
    result.writeln('  ];\n');
  }

  // Generate the router method:
  result.writeln('  static List<OneDimenDataType> exercise(int type) {');
  result.writeln('    switch (type) {');

  schemaMap.forEach((schemaName, baseName) {
    final cleanBase =
        baseName.substring(0, 1).toLowerCase() + baseName.substring(1);
    final types = sportTypeMap[cleanBase];
    if (types != null && types.isNotEmpty) {
      for (final t in types) {
        result.writeln('      case $t:');
      }
      result.writeln('        return _$schemaName;');
    }
  });

  result.writeln('      default:');
  result.writeln('        return _exercise;');
  result.writeln('    }');
  result.writeln('  }');
  result.writeln('');

  // Default exercise fallback schema
  result.writeln('''  static const _exercise = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(5, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
  ];
}
''');

  File('lib/health/parsers/schemas.dart').writeAsStringSync(result.toString());
  print('schemas.dart generated successfully!');
}
