import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

// ── File output ──────────────────────────────────────────────────────────────

class _FileOutput extends LogOutput {
  _FileOutput(this._file);

  final File _file;
  final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  @override
  void output(OutputEvent event) {
    final time = _fmt.format(DateTime.now());
    final level = event.level.name.toUpperCase().padRight(7);
    final lines = event.lines.join('\n');
    _file.writeAsStringSync('[$time] $level $lines\n',
        mode: FileMode.append, flush: true);
  }
}

// ── Console + File output ─────────────────────────────────────────────────────

class _MultiOutput extends LogOutput {
  _MultiOutput(this._outputs);
  final List<LogOutput> _outputs;

  @override
  void output(OutputEvent event) {
    for (final o in _outputs) {
      o.output(event);
    }
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

late Logger logger;

/// Call once from main() before runApp().
Future<void> initLogger() async {
  // Logs subfolder next to the .exe
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final logsDir = Directory('$exeDir/Logs');
  if (!logsDir.existsSync()) logsDir.createSync();

  final stamp = DateFormat('yyMMddHHmm').format(DateTime.now());
  final file = File('${logsDir.path}/$stamp-Logs.txt');

  // Write header
  file.writeAsStringSync(
    '=== TIQN Attendance Log — started ${DateTime.now()} ===\n',
    mode: FileMode.write,
  );

  logger = Logger(
    level: Level.trace,
    filter: ProductionFilter(), // logs all levels even in release
    printer: SimplePrinter(printTime: false, colors: false),
    output: _MultiOutput([
      ConsoleOutput(),
      _FileOutput(file),
    ]),
  );

  logger.i('Log file: ${file.path}');

  // Delete log files older than 7 days
  _deleteOldLogs(logsDir);
}

void _deleteOldLogs(Directory logsDir) {
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final logPattern = RegExp(r'^\d{10}-Logs\.txt$');
  try {
    logsDir
        .listSync()
        .whereType<File>()
        .where((f) => logPattern.hasMatch(f.uri.pathSegments.last))
        .where((f) => f.statSync().modified.isBefore(cutoff))
        .forEach((f) {
      f.deleteSync();
      logger.i('Deleted old log: ${f.path}');
    });
  } catch (e) {
    logger.w('Failed to clean old logs: $e');
  }
}
