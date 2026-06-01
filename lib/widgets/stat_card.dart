import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_theme.dart';
import '../providers/fleet_provider.dart';

// ── Stat Card Widget ──────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     loading;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          loading
            ? Shimmer.fromColors(
                baseColor: AppTheme.card,
                highlightColor: AppTheme.border,
                child: Container(height: 28, width: 40, decoration: BoxDecoration(
                  color: AppTheme.card, borderRadius: BorderRadius.circular(6))))
            : Text(value, style: TextStyle(
                color: color, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Router Tile Widget ────────────────────────────────────────────────────────
class RouterTile extends StatelessWidget {
  final RouterDevice router;
  final VoidCallback onTap;

  const RouterTile({super.key, required this.router, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: router.isOnline
              ? AppTheme.green.withOpacity(0.2)
              : AppTheme.red.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: router.isOnline ? AppTheme.green : AppTheme.red,
                boxShadow: [BoxShadow(
                  color: (router.isOnline ? AppTheme.green : AppTheme.red).withOpacity(0.4),
                  blurRadius: 6,
                )],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(router.name,
                    style: const TextStyle(color: AppTheme.text1,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${router.ip}  •  ${router.model.isNotEmpty ? router.model : "—"}',
                    style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
                ],
              ),
            ),
            // Latency
            if (router.isOnline && router.latency != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _latColor(router.latency!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _latColor(router.latency!).withOpacity(0.3)),
                ),
                child: Text('${router.latency!.round()}ms',
                  style: TextStyle(color: _latColor(router.latency!),
                    fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.text2, size: 18),
          ],
        ),
      ),
    );
  }

  Color _latColor(double ms) {
    if (ms < 50)  return AppTheme.green;
    if (ms < 150) return AppTheme.yellow;
    return AppTheme.red;
  }
}

// ── Shimmer Loading Tile ──────────────────────────────────────────────────────
class ShimmerRouterTile extends StatelessWidget {
  const ShimmerRouterTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.card,
      highlightColor: AppTheme.border,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        height: 62,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ── Grade Badge ───────────────────────────────────────────────────────────────
class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = {'A': AppTheme.green, 'B': AppTheme.accent,
      'C': AppTheme.yellow, 'F': AppTheme.red}[grade] ?? AppTheme.text2;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Text(grade,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(children: [
        Container(width: 3, height: 16,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(2),
          )),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
          color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 14)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
        const Spacer(),
        Text(value, style: TextStyle(
          color: valueColor ?? AppTheme.text1,
          fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
