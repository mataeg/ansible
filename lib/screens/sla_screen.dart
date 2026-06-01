import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../providers/fleet_provider.dart';
import '../widgets/stat_card.dart';

class SlaScreen extends ConsumerWidget {
  const SlaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaAsync = ref.watch(slaProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 SLA Dashboard'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(slaProvider),
          ),
        ],
      ),
      body: slaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error:   (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: AppTheme.red))),
        data: (data) {
          final devices = (data['devices'] as List?) ?? [];
          final summary = (data['summary'] as Map?) ?? {};
          return CustomScrollView(
            slivers: [
              // KPI Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: StatCard(
                        value: '${summary['avg_uptime'] ?? 0}%',
                        label: 'متوسط Uptime',
                        icon: Icons.trending_up, color: AppTheme.green)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(
                        value: '${summary['avg_latency'] ?? 0}ms',
                        label: 'متوسط التأخير',
                        icon: Icons.speed, color: AppTheme.accent)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: StatCard(
                        value: '${summary['incidents'] ?? 0}',
                        label: 'إجمالي الحوادث',
                        icon: Icons.warning_amber, color: AppTheme.yellow)),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(
                        value: '${summary['flapping'] ?? 0}',
                        label: 'متقطع (Flapping)',
                        icon: Icons.sync_problem, color: AppTheme.red)),
                    ]),
                  ]),
                ),
              ),
              // Devices list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _SlaRow(device: devices[i] as Map<String, dynamic>),
                    childCount: devices.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }
}

class _SlaRow extends StatelessWidget {
  final Map<String, dynamic> device;
  const _SlaRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final grade    = device['grade'] as String? ?? '—';
    final uptime   = device['uptime_pct'] as num?;
    final latency  = device['latency_avg'] as num?;
    final status   = device['status'] as String? ?? 'unknown';
    final gradeColor = {'A': AppTheme.green, 'B': AppTheme.accent,
      'C': AppTheme.yellow, 'F': AppTheme.red}[grade] ?? AppTheme.text2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        // Grade circle
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: gradeColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: gradeColor.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(device['name'] as String? ?? '—',
              style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == 'online' ? AppTheme.green : status == 'flapping' ? AppTheme.yellow : AppTheme.red,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          if (uptime != null) ...[
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: uptime / 100,
                  backgroundColor: AppTheme.border,
                  color: uptime >= 99 ? AppTheme.green : uptime >= 80 ? AppTheme.yellow : AppTheme.red,
                  minHeight: 5,
                ),
              )),
              const SizedBox(width: 8),
              Text('${uptime}%',
                style: const TextStyle(color: AppTheme.text2, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],
        ])),
        if (latency != null)
          Text('${latency}ms',
            style: const TextStyle(color: AppTheme.text2, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }
}
