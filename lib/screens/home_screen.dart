import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/fleet_provider.dart';
import '../core/app_updater.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String appVersion = '1.0.3';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(fleetProvider.notifier).refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final data = await ref.read(apiClientProvider).checkAppVersion();
      if (data['ok'] == true) {
        final latestVersion = data['version'] as String;
        final downloadUrl = data['download_url'] as String;
        if (latestVersion != appVersion && mounted) {
          _showUpdateDialog(latestVersion, downloadUrl);
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                'تحديث جديد متاح!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.text1,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يتوفر إصدار جديد من التطبيق ($version). يُرجى التحديث للحصول على آخر الميزات والتحسينات والاستقرار.',
                style: const TextStyle(color: AppTheme.text2, fontSize: 14, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً', style: TextStyle(color: AppTheme.text2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                AppUpdater.startUpdate(context, url, version);
              },
              child: const Text('تنزيل الآن', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_outlined, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Text('EasyBill لوحة التحكم'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(fleetProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: () => ref.read(fleetProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Welcome Banner ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2042), Color(0xFF0D1B36)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحباً بك في نظام إدارة الشبكات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('تابع وأدر أسطول أجهزة MikroTik بكل سهولة عبر لوحة التحكم السريعة.', style: TextStyle(color: AppTheme.text2, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _smallStat('متصل', '${fleet.onlineCount}', AppTheme.green),
                      const SizedBox(width: 14),
                      _smallStat('فاصل', '${fleet.offlineCount}', AppTheme.red),
                      const SizedBox(width: 14),
                      _smallStat('الإجمالي', '${fleet.total}', AppTheme.accent),
                    ],
                  )
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 20),

            const Text('الخدمات والوظائف الرئيسية', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),

            // ── Grid of Menu Tiles ──────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _dashboardCard(
                  title: 'أجهزة المايكروتيك',
                  subtitle: '${fleet.total} أجهزة مسجلة',
                  icon: Icons.router,
                  color: AppTheme.accent,
                  onTap: () => context.push('/mikrotik'),
                ).animate().fadeIn(delay: 50.ms),
                _dashboardCard(
                  title: 'الامتثال والأمان',
                  subtitle: 'فحوصات ZTP و SSTP',
                  icon: Icons.verified_outlined,
                  color: AppTheme.green,
                  onTap: () => context.push('/compliance'),
                ).animate().fadeIn(delay: 100.ms),
                _dashboardCard(
                  title: 'مستويات الخدمة SLA',
                  subtitle: 'تقارير أوقات التشغيل',
                  icon: Icons.bar_chart,
                  color: AppTheme.yellow,
                  onTap: () => context.push('/sla'),
                ).animate().fadeIn(delay: 150.ms),
                _dashboardCard(
                  title: 'إدارة البلاغات',
                  subtitle: 'تذاكر الدعم والأعطال',
                  icon: Icons.confirmation_number_outlined,
                  color: const Color(0xFFFF8A00),
                  onTap: () => context.push('/tickets'),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),

            const SizedBox(height: 12),

            _fullWidthCard(
              title: 'إعدادات النظام والأتمتة',
              subtitle: 'تحديد فترات الإصلاح التلقائي وتفعيل تقارير التلجرام',
              icon: Icons.settings_outlined,
              color: Colors.purpleAccent,
              onTap: () => context.push('/settings'),
            ).animate().fadeIn(delay: 250.ms),

            if (ref.watch(authProvider).isAdmin) ...[
              const SizedBox(height: 12),
              _fullWidthCard(
                title: 'إدارة المستخدمين والمديرين',
                subtitle: 'إضافة فنيين ومدراء جدد وإعادة تعيين كلمات المرور للصلاحيات المختلفة',
                icon: Icons.manage_accounts_outlined,
                color: AppTheme.purple,
                onTap: () => context.push('/managers'),
              ).animate().fadeIn(delay: 300.ms),
            ],

            const SizedBox(height: 24),
            Center(
              child: Text(
                'إصدار التطبيق v$appVersion — EasyBill Fleet',
                style: const TextStyle(color: AppTheme.text2, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _dashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _fullWidthCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.text2, size: 12),
          ],
        ),
      ),
    );
  }
}
