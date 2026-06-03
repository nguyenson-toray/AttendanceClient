import 'dart:io';
import 'dart:async';
import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/appLogger.dart';
import 'package:attandance_client/globalValue.dart';
import 'package:attandance_client/model/mongoDb.dart';
import 'package:attandance_client/services/update_service.dart';
import 'package:attandance_client/ui/att.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';

Future<void> main() async {
  // Catch all other async/isolate errors
  runZonedGuarded(
    _run,
    (error, stack) =>
        logger.e('Unhandled exception', error: error, stackTrace: stack),
  );
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLogger();

  // Catch Flutter framework errors
  FlutterError.onError = (details) {
    logger.e(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    // WindowOptions windowOptions = const WindowOptions(
    //   center: true,
    //   backgroundColor: Colors.blueGrey,
    //   skipTaskbar: false,
    //   titleBarStyle: TitleBarStyle.normal,
    // );
    // await windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager
    //       .maximize(); // Forces the window to maximize and fit the screen
    //   await windowManager.show();
    //   await windowManager.focus();
    // });
    WindowManager.instance.setTitle('TIQN Attendance - Dev by IT Team');
  }
  await initPackageInfo();
  App.gValue.pcName = Platform.localHostname;

  // Developer: choose server IP before connecting
  if (App.gValue.pcName == 'PC-82') {
    final ip = await _showServerDialog();
    App.mongoDb.ipServerOverride = ip;
  }

  // Check for update from server
  final currentVersion =
      '${App.gValue.packageInfo.version}+${App.gValue.packageInfo.buildNumber}';
  App.gValue.pendingUpdate = await checkForUpdate(currentVersion);

  runApp(App());
}

extension LocalDateTimeToUTC on DateTime {
  DateTime toUtcKeepValue() => DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  );
  DateTime toBeginDay() => DateTime.utc(year, month, day, 0, 0, 0, 0, 0);
  DateTime toEndDay() => DateTime.utc(year, month, day, 23, 59, 59, 0, 0);
}

Future<void> initPackageInfo() async {
  App.gValue.packageInfo = await PackageInfo.fromPlatform();
}

Future<String> _showServerDialog() async {
  final completer = Completer<String>();
  runApp(
    MaterialApp(
      home: Builder(
        builder: (context) {
          // Show dialog once after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Developer — Choose Server'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud),
                      title: const Text('10.0.1.4 (Production)'),
                      onTap: () => Navigator.pop(ctx, '10.0.1.4'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.computer),
                      title: const Text('localhost'),
                      onTap: () => Navigator.pop(ctx, 'localhost'),
                    ),
                  ],
                ),
              ),
            ).then((value) => completer.complete(value ?? 'localhost'));
          });
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return completer.future;
}

class App extends StatelessWidget {
  const App({super.key});
  static var gValue = GValue();
  static var mongoDb = MongoDb();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return OKToast(
      child: MaterialApp(
        title: 'TIQN Attendance',
        theme: _buildLightTheme(),
        home: LoaderOverlay(child: Att()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.primary,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgPage,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 20,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.primary),
        shape: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.07),
        ),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Card — flat, border mảnh, bo 12px
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),

      // DataTable
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.primaryTint),
        headingTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.surfaceAlt;
          }
          return AppColors.surface;
        }),
        dataTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        dividerThickness: 0.5,
        horizontalMargin: 16,
        columnSpacing: 24,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryTint,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(4),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: AppColors.onPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dialog — bóng nhẹ, bo 16px
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.onPrimary, fontSize: 12),
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        labelLarge: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
