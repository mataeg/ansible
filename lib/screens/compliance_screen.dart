import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';

class ComplianceScreen extends ConsumerStatefulWidget {
  const ComplianceScreen({super.key});

  @override
  ConsumerState<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends ConsumerState<ComplianceScreen> {
  List<dynamic> _devices = [];
  Map<String, dynamic> _summary = {};
  bool _loading   = false;
  bool _scanned   = false;

  Future<void> _scan() async {
    setState(() { _loading = true; _scanned = false; });
    try {
      final data = await ref.read(apiClientProvider).getCompliance();
      if (mounted) setState(() {
        _devices = data['devices'] as List? ?? [];
        _summary = data['summary'] as Map<String, dynamic>? ?? {};
        _loading = false;
        _scanned = true;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e', style: const TextStyle(color: AppTheme.red))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('📋 تقرير الامتثال'),
      ),
      body: Column(
        children: [
          // Scan button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _scan,
              icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
              label: Text(_loading ? 'جاري الفحص...' : '🔍 بدء فحص الامتثال'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _loading ? AppTheme.text2 : AppTheme.accent,
              ),
            ),
          ),

          // Summary
          if (_scanned) Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              _sumCard('${_summary['compliant']}', 'مستوفية', AppTheme.green),
              const SizedBox(width: 8),
              _sumCard('${_summary['warning']}', 'تحذيرات', AppTheme.yellow),
              const SizedBox(width: 8),
              _sumCard('${_summary['critical']}', 'حرجة', AppTheme.red),
              const SizedBox(width: 8),
              _sumCard('${_summary['unreachable']}', 'غير متاحة', AppTheme.text2),
            ]),
          ),

          // Results
          Expanded(
            child: !_scanned
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_outlined, color: AppTheme.text2, size: 64),
                  const SizedBox(height: 16),
                  const Text('اضغط "بدء فحص الامتثال"', style: TextStyle(color: AppTheme.text2)),
                  const SizedBox(height: 8),
                  const Text('سيتم فحص كل الأجهزة عبر RouterOS API',
                    style: TextStyle(color: AppTheme.text2, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) => _DeviceCompRow(device: _devices[i] as Map<String, dynamic>),
                ),
          ),
        ],
      ),
    );
  }

  Widget _sumCard(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
        Text(label, style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
      ]),
    ),
  );
}

class _DeviceCompRow extends StatelessWidget {
  final Map<String, dynamic> device;
  const _DeviceCompRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final grade    = device['grade'] as String? ?? '—';
    final issues   = device['issues'] as List? ?? [];
    final checks   = device['checks'] as Map? ?? {};
    final gc       = {'A': AppTheme.green, 'B': AppTheme.accent,
      'C': AppTheme.yellow, 'F': AppTheme.red, '—': AppTheme.text2}[grade] ?? AppTheme.text2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: gc.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: gc.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(grade, style: TextStyle(color: gc, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        title: Text(device['name'] as String? ?? '—',
          style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(device['ip'] as String? ?? '—',
          style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
        trailing: Text('${issues.length} ${issues.isEmpty ? '✅' : '⚠️'}',
          style: TextStyle(color: issues.isEmpty ? AppTheme.green : AppTheme.yellow, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Check icons row
                Wrap(spacing: 8, children: checks.entries.map((e) {
                  final ok = e.value['ok'];
                  final detail = e.value['detail'] as String? ?? '';
                  return Tooltip(
                    message: '${e.key}: $detail',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text('${ok == true ? '✅' : ok == false ? '❌' : '⚠️'} ${e.key}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.text2)),
                    ),
                  );
                }).toList()),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...issues.map((iss) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(iss as String,
                        style: const TextStyle(color: AppTheme.red, fontSize: 11))),
                    ]),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
