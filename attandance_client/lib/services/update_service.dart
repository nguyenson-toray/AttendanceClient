import 'dart:io';
import 'dart:math';
import 'package:attandance_client/appLogger.dart';
import 'package:attandance_client/main.dart';

class UpdateInfo {
  final String serverVersion;
  final String localVersion;

  UpdateInfo({required this.serverVersion, required this.localVersion});
}

/// Check if a new version is available on server.
/// Returns UpdateInfo if update available, null otherwise.
Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
  try {
    final serverExePath = App.gValue.serverExePath;
    // Check server accessibility
    if (!File(serverExePath).existsSync()) {
      logger.i('[Update] Server không kết nối được, bỏ qua kiểm tra.');
      return null;
    }

    // Get server exe version via PowerShell
    final serverVersion = await _getExeVersion(serverExePath);
    if (serverVersion == null) {
      logger.w('[Update] Không đọc được version từ server exe.');
      return null;
    }

    logger.i('[Update] Local: $currentVersion | Server: $serverVersion');

    // Compare versions
    if (_compareVersions(currentVersion, serverVersion) < 0) {
      return UpdateInfo(
        serverVersion: serverVersion,
        localVersion: currentVersion,
      );
    }

    return null;
  } catch (e) {
    logger.w('[Update] Lỗi kiểm tra update: $e');
    return null;
  }
}

/// Perform the update: create a temp script, run it detached, then exit app.
Future<void> performUpdate() async {
  final tempDir = Directory.systemTemp;
  final scriptFile = File('${tempDir.path}\\att_update.bat');

  final serverFolder = App.gValue.serverFolder;
  final localFolder = App.gValue.localFolder;
  final localExe = App.gValue.localExePath;

  final scriptContent = '''
@echo off
chcp 65001 >nul
echo [INFO] Dang cap nhat Attendance App...
timeout /t 2 /nobreak >nul
xcopy "$serverFolder\\*" "$localFolder\\" /E /Y /I /Q
if errorlevel 1 (
    echo [ERROR] Cap nhat that bai!
    pause
    exit /b 1
)
echo [INFO] Cap nhat thanh cong! Dang khoi dong lai...
start "" "$localExe"
del "%~f0"
''';

  await scriptFile.writeAsString(scriptContent);

  await Process.start(
    'cmd',
    ['/c', scriptFile.path],
    mode: ProcessStartMode.detached,
  );

  exit(0);
}

/// Read ProductVersion from an exe file using PowerShell.
Future<String?> _getExeVersion(String exePath) async {
  final result = await Process.run('powershell', [
    '-nologo',
    '-noprofile',
    '-command',
    "[System.Diagnostics.FileVersionInfo]::GetVersionInfo('$exePath').ProductVersion",
  ]);
  if (result.exitCode == 0) {
    final version = (result.stdout as String).trim();
    if (version.isNotEmpty) return version;
  }
  return null;
}

/// Compare versions like "3.0.0+1" vs "3.1.0+2".
/// Returns: negative (local older), 0 (equal), positive (local newer).
int _compareVersions(String local, String server) {
  final lp = _normalize(local);
  final sp = _normalize(server);
  final len = max(lp.length, sp.length);
  for (int i = 0; i < len; i++) {
    final l = i < lp.length ? lp[i] : 0;
    final s = i < sp.length ? sp[i] : 0;
    if (l < s) return -1;
    if (l > s) return 1;
  }
  return 0;
}

List<int> _normalize(String version) {
  return version.replaceAll('+', '.').split('.').map((s) => int.tryParse(s) ?? 0).toList();
}
