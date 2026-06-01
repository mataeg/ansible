import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/device_detail_screen.dart';
import '../screens/sla_screen.dart';
import '../screens/tickets_screen.dart';
import '../screens/compliance_screen.dart';
import '../screens/settings_screen.dart';
import '../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (ctx, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/device/:name',
        builder: (ctx, state) => DeviceDetailScreen(
          routerName: state.pathParameters['name']!,
          routerIp: state.uri.queryParameters['ip'] ?? '',
        ),
      ),
      GoRoute(
        path: '/sla',
        builder: (ctx, state) => const SlaScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (ctx, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/compliance',
        builder: (ctx, state) => const ComplianceScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const SettingsScreen(),
      ),
    ],
  );
});
