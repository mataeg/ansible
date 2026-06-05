import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../providers/fleet_provider.dart';
import '../widgets/stat_card.dart';

class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(fleetProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);

    final filtered = fleet.routers.where((r) {
      if (_filter.isEmpty) return true;
      return r.name.toLowerCase().contains(_filter) ||
             r.ip.contains(_filter) ||
             r.model.toLowerCase().contains(_filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('📋 قائمة أجهزة المايكروتيك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(fleetProvider.notifier).refresh(),
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
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.router_outlined, size: 48, color: AppTheme.text2.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text('لا توجد أجهزة متطابقة مع البحث', style: TextStyle(color: AppTheme.text2, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final r = filtered[i];
                    return RouterTile(
                      router: r,
                      onTap: () => context.push('/device/${Uri.encodeComponent(r.name)}?ip=${r.ip}'),
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
