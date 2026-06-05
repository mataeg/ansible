import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../widgets/stat_card.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final String routerName;
  final String routerIp;

  const DeviceDetailScreen({
    super.key,
    required this.routerName,
    required this.routerIp,
  });

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _info;
  List<dynamic> _notes   = [];
  List<dynamic> _tickets = [];
  Map<String, dynamic>? _health;
  bool _loadingInfo   = true;
  bool _loadingHealth = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final api = ref.read(apiClientProvider);
    try {
      final info    = await api.getDeviceInfo(widget.routerName);
      final notes   = await api.getNotes(widget.routerName);
      final tickets = await api.getDeviceTickets(widget.routerName);
      if (mounted) setState(() {
        _info       = info;
        _notes      = notes;
        _tickets    = tickets;
        _loadingInfo = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _runHealthCheck() async {
    setState(() => _loadingHealth = true);
    try {
      final res = await ref.read(apiClientProvider).healthCheck(widget.routerName);
      if (mounted) setState(() {
        _health        = res;
        _loadingHealth = false;
      });
      _showHealthDialog();
    } catch (e) {
      if (mounted) setState(() => _loadingHealth = false);
      _showSnack('تعذّر تشغيل Health Check');
    }
  }

  void _showHealthDialog() {
    if (_health == null) return;
    final checks = (_health!['checks'] as Map<String, dynamic>?) ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('🏥 Health Check — ${widget.routerName}',
              style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            ...checks.entries.map((e) {
              final ok   = e.value['ok'];
              final detail = e.value['detail'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Text(ok == true ? '✅' : ok == false ? '❌' : '⚠️', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: const TextStyle(color: AppTheme.text1, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (detail.isNotEmpty)
                        Text(detail, style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
                    ],
                  )),
                ]),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addNote() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('إضافة ملاحظة', style: TextStyle(color: AppTheme.text1)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.text1),
          decoration: const InputDecoration(hintText: 'اكتب الملاحظة...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(apiClientProvider).addNote(widget.routerName, ctrl.text.trim());
      final notes = await ref.read(apiClientProvider).getNotes(widget.routerName);
      if (mounted) setState(() => _notes = notes);
      _showSnack('✅ تمت إضافة الملاحظة');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _info?['ok'] == true;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: AppTheme.text1),
        title: Column(
          children: [
            Text(widget.routerName, style: const TextStyle(fontSize: 14)),
            Text(widget.routerIp,
              style: const TextStyle(color: AppTheme.text2, fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          // Health Check button
          IconButton(
            icon: _loadingHealth
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.green))
              : const Icon(Icons.health_and_safety_outlined, color: AppTheme.green),
            onPressed: _loadingHealth ? null : _runHealthCheck,
            tooltip: 'Health Check',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.text2,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(text: 'معلومات'),
            Tab(text: 'ملاحظات'),
            Tab(text: 'بلاغات'),
          ],
        ),
      ),
      body: _loadingInfo
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : TabBarView(
            controller: _tabs,
            children: [
              _InfoTab(info: _info, isOnline: isOnline),
              _NotesTab(notes: _notes, onAdd: _addNote,
                onDelete: (id) async {
                  await ref.read(apiClientProvider).deleteNote(widget.routerName, id);
                  final notes = await ref.read(apiClientProvider).getNotes(widget.routerName);
                  if (mounted) setState(() => _notes = notes);
                }),
              _TicketsTab(tickets: _tickets, routerName: widget.routerName,
                onRefresh: () async {
                  final t = await ref.read(apiClientProvider).getDeviceTickets(widget.routerName);
                  if (mounted) setState(() => _tickets = t);
                }),
            ],
          ),
    );
  }
}

// ── Info Tab ──────────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final Map<String, dynamic>? info;
  final bool isOnline;
  const _InfoTab({this.info, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (info == null) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppTheme.text2)));
    
    final facts = info!['facts'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (isOnline ? AppTheme.green : AppTheme.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (isOnline ? AppTheme.green : AppTheme.red).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? AppTheme.green : AppTheme.red, size: 20),
              const SizedBox(width: 8),
              Text(isOnline ? 'متصل ومستقر ✓' : 'فاصل API / غير متصل',
                style: TextStyle(
                  color: isOnline ? AppTheme.green : AppTheme.red,
                  fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
        if (!isOnline) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تعذر الاتصال بـ RouterOS API عبر منفذ 8728/8729. قد يكون الجهاز غير متصل أو الـ API معطل.',
                    style: TextStyle(color: Colors.orange, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _card([
          InfoRow(label: 'الـ IP',     value: info!['ip']      ?? '—'),
          InfoRow(label: 'الموديل',   value: (facts?['board'] as String?) ?? info!['model'] ?? '—'),
          InfoRow(label: 'الإصدار',   value: (facts?['version'] as String?) ?? '—'),
          InfoRow(label: 'المعرّف',   value: info!['name']    ?? '—'),
        ]),
        if (isOnline && facts != null) ...[
          const SizedBox(height: 12),
          _card([
            InfoRow(
              label: 'حمل المعالج (CPU Load)',
              value: '${facts['cpu_load'] ?? 0}%',
            ),
            InfoRow(
              label: 'الذاكرة الحرة (Free Memory)',
              value: '${(((facts['free_mem'] ?? 0) as num) / 1024 / 1024).toStringAsFixed(1)} MB / ${(((facts['total_mem'] ?? 0) as num) / 1024 / 1024).toStringAsFixed(1)} MB',
            ),
            InfoRow(
              label: 'المساحة الحرة (Free Disk)',
              value: '${(((facts['free_hdd'] ?? 0) as num) / 1024 / 1024).toStringAsFixed(1)} MB / ${(((facts['total_hdd'] ?? 0) as num) / 1024 / 1024).toStringAsFixed(1)} MB',
            ),
            InfoRow(
              label: 'المعمارية (Arch)',
              value: facts['arch'] ?? '—',
            ),
          ]),
        ],
        if (isOnline && facts?['uptime'] != null) ...[
          const SizedBox(height: 12),
          _card([InfoRow(label: 'مدة التشغيل (Uptime)', value: facts!['uptime'] ?? '—')]),
        ],
      ],
    );
  }

  Widget _card(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: rows
      .expand((w) => [w, const Divider(height: 1)])
      .take(rows.length * 2 - 1)
      .toList()),
  );
}

// ── Notes Tab ─────────────────────────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final List<dynamic> notes;
  final VoidCallback  onAdd;
  final Function(int) onDelete;
  const _NotesTab({required this.notes, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: notes.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.note_outlined, color: AppTheme.text2, size: 48),
                const SizedBox(height: 10),
                const Text('لا توجد ملاحظات', style: TextStyle(color: AppTheme.text2)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notes.length,
                itemBuilder: (ctx, i) {
                  final n = notes[i] as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['text'] ?? '', style: const TextStyle(color: AppTheme.text1, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(n['created_at'] ?? '', style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => onDelete(n['id'] as int),
                          child: const Icon(Icons.delete_outline, color: AppTheme.red, size: 18)),
                      ]),
                    ]),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('إضافة ملاحظة'),
          ),
        ),
      ],
    );
  }
}

// ── Tickets Tab ───────────────────────────────────────────────────────────────
class _TicketsTab extends StatelessWidget {
  final List<dynamic> tickets;
  final String routerName;
  final VoidCallback onRefresh;
  const _TicketsTab({required this.tickets, required this.routerName, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: tickets.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.confirmation_number_outlined, color: AppTheme.text2, size: 48),
              const SizedBox(height: 10),
              const Text('لا توجد بلاغات', style: TextStyle(color: AppTheme.text2)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (ctx, i) {
                final t = tickets[i] as Map<String, dynamic>;
                final isOpen = t['status'] == 'open';
                final pc = _priorityColor(t['priority'] as String? ?? 'medium');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      top: const BorderSide(color: AppTheme.border),
                      bottom: const BorderSide(color: AppTheme.border),
                      left: const BorderSide(color: AppTheme.border),
                      right: BorderSide(color: pc, width: 3),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(t['title'] ?? '',
                        style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 13))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isOpen ? AppTheme.accent : AppTheme.text2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(isOpen ? 'مفتوح' : 'مغلق',
                          style: TextStyle(
                            color: isOpen ? AppTheme.accent : AppTheme.text2, fontSize: 10)),
                      ),
                    ]),
                    if ((t['desc'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(t['desc'] as String,
                        style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    Text(t['created_at'] ?? '', style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                  ]),
                );
              },
            ),
      ),
    ]);
  }

  Color _priorityColor(String p) => const {
    'critical': AppTheme.red,
    'high': Color(0xFFF97316),
    'medium': AppTheme.yellow,
    'low': AppTheme.green,
  }[p] ?? AppTheme.text2;
}
