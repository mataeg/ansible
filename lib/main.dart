import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/app_theme.dart';
import 'core/api_client.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Riverpod ProviderContainer
  final container = ProviderContainer();

  // Load saved server URL
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) {
      container.read(serverUrlProvider.notifier).state = saved;
    }
  } catch (e) {
    debugPrint('Failed to load server URL: $e');
  }

  // Set up Global Crash Reporter
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportGlobalError(container, details.exception.toString(), details.stack?.toString() ?? '');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _reportGlobalError(container, error.toString(), stack.toString());
    return false; // let the app print to console/crash normally
  };

  runApp(ProviderScope(
    parent: container,
    child: const FleetApp(),
  ));
}

void _reportGlobalError(ProviderContainer container, String error, String stack) {
  try {
    final auth = container.read(authProvider);
    final username = auth.username.isNotEmpty ? auth.username : 'anonymous';
    
    container.read(apiClientProvider).reportAppLog(
      error: error,
      stack: stack,
      username: username,
      deviceInfo: {
        'platform': 'Android',
        'build': 'release',
      },
    ).catchError((e) {
      debugPrint('Failed to report app log: $e');
    });
  } catch (e) {
    debugPrint('Crash reporter encountered error: $e');
  }
}

class FleetApp extends ConsumerWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'EasyBill Fleet Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
