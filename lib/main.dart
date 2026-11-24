
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'services/habit_repository.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.black,
    systemNavigationBarContrastEnforced: false,
  ));

  runApp(const CanopyApp());
}

class CanopyApp extends StatefulWidget {
  const CanopyApp({super.key});

  @override
  State<CanopyApp> createState() => _CanopyAppState();
}

class _CanopyAppState extends State<CanopyApp> {
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initializeStartup();
  }

  Future<void> _initializeStartup() async {
    await SettingsService().init();
    await NotificationService().init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HabitRepository()..load(),
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: FutureBuilder<void>(
          future: _startupFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'CANOPY could not finish starting.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: SizedBox.expand(),
              );
            }

            return const MainNavigation();
          },
        ),
      ),
    );
  }
}



