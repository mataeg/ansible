import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/fleet_provider.dart';
import '../core/app_updater.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = '';
  int _navIndex = 0;
  static const String appVersion = '1.0.0';

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth  = ref.watch(authProvider);
    final fleet = ref.watch(fleetProvider);

    final filtered = fleet.routers.where((r) {
      if (_filter.isEmpty) return true;
      return r.name.toLowerCase().contains(_filter) ||
             r.ip.contains(_filter) ||
             r.model.toLowerCase().contains(_filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.router, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Text('EasyBill Fleet'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${fleet.total}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
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
        child: CustomScrollView(
          slivers: [
            // ── Stats Row ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(child: StatCard(
                      value: '${fleet.onlineCount}',
                      label: 'متصل',
                      icon: Icons.circle,
                      color: AppTheme.green,
                      loading: fleet.isLoading,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(
                      value: '${fleet.offlineCount}',
                      label: 'فاصل',
                      icon: Icons.circle,
                      color: AppTheme.red,
                      loading: fleet.isLoading,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(
                      value: '${fleet.total}',
                      label: 'الإجمالي',
                      icon: Icons.router,
                      color: AppTheme.accent,
                      loading: fleet.isLoading,
                    )),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            // ── Quick Nav ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    _QuickBtn(label: 'SLA', icon: Icons.bar_chart, onTap: () => context.go('/sla')),
                    const SizedBox(width: 8),
                    _QuickBtn(label: 'بلاغات', icon: Icons.confirmation_number_outlined, onTap: () => context.go('/tickets')),
                    const SizedBox(width: 8),
                    _QuickBtn(label: 'امتثال', icon: Icons.verified_outlined, onTap: () => context.go('/compliance')),
                    const SizedBox(width: 8),
                    _QuickBtn(label: 'إعدادات', icon: Icons.settings_outlined, onTap: () => context.go('/settings')),
                  ],
                ),
              ),
            ),

            // ── Search ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _filter = v.toLowerCase()),
                  style: const TextStyle(color: AppTheme.text1, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث في الأجهزة...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.text2, size: 20),
                    suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.text2, size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _filter = ''); })
                      : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (fleet.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                    ),
                    child: Text(fleet.error!,
                      style: const TextStyle(color: AppTheme.red, fontSize: 12)),
                  ),
                ),
              ),

            // ── Router List ───────────────────────────────────────────────
            if (fleet.isLoading && fleet.routers.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => const ShimmerRouterTile(),
                  childCount: 8,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final r = filtered[i];
                    return RouterTile(
                      router: r,
                      onTap: () => context.go('/device/${Uri.encodeComponent(r.name)}?ip=${r.ip}'),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
                  },
                  childCount: filtered.length,
                ),
              ),

            // Last update
            if (fleet.lastUpdate != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'آخر تحديث: ${_fmtTime(fleet.lastUpdate!)}',
                    style: const TextStyle(color: AppTheme.text2, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.text1, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}
