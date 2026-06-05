import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/mikrotik_dashboard_screen.dart';
import '../screens/device_list_screen.dart';
import '../screens/sstp_discovery_screen.dart';
import '../screens/device_detail_screen.dart';
import '../screens/sla_screen.dart';
import '../screens/tickets_screen.dart';
import '../screens/compliance_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/managers_screen.dart';
import '../screens/ansible_playbooks_screen.dart';
import '../screens/hotspot_files_screen.dart';
import '../screens/operations_screen.dart';
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
        path: '/mikrotik',
        builder: (ctx, state) => const MikrotikDashboardScreen(),
      ),
      GoRoute(
        path: '/mikrotik/devices',
        builder: (ctx, state) => const DeviceListScreen(),
      ),
      GoRoute(
        path: '/mikrotik/discover',
        builder: (ctx, state) => const SstpDiscoveryScreen(),
      ),
      GoRoute(
        path: '/mikrotik/playbooks',
        builder: (ctx, state) => const AnsiblePlaybooksScreen(),
      ),
      GoRoute(
        path: '/mikrotik/hotspot-files',
        builder: (ctx, state) => const HotspotFilesScreen(),
      ),
      GoRoute(
        path: '/mikrotik/operations',
        builder: (ctx, state) => const OperationsScreen(),
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
      GoRoute(
        path: '/managers',
        builder: (ctx, state) => const ManagersScreen(),
      ),
    ],
  );
});
