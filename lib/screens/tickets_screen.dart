import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String _filter = 'all'; // all | open | closed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await ref.read(apiClientProvider).getAllTickets();
      if (mounted) setState(() { _tickets = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeTicket(String router, int id) async {
    await ref.read(apiClientProvider).closeTicket(router, id);
    _load();
  }

  List<dynamic> get _filtered {
    if (_filter == 'all') return _tickets;
    return _tickets.where((t) => t['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _tickets.where((t) => t['status'] == 'open').length;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎫 البلاغات'),
          if (openCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$openCount',
                style: const TextStyle(color: AppTheme.red, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _chip('الكل',   'all'),
              const SizedBox(width: 8),
              _chip('مفتوح', 'open'),
              const SizedBox(width: 8),
              _chip('مغلق',  'closed'),
            ]),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
              : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.confirmation_number_outlined, color: AppTheme.text2, size: 52),
                    const SizedBox(height: 12),
                    const Text('لا توجد بلاغات', style: TextStyle(color: AppTheme.text2)),
                  ]))
                : RefreshIndicator(
                    color: AppTheme.accent,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final t = _filtered[i] as Map<String, dynamic>;
                        return _TicketCard(ticket: t,
                          onClose: () => _closeTicket(t['router'] as String, t['id'] as int));
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTicket,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add),
        label: const Text('بلاغ جديد'),
      ),
    );
  }

  Widget _chip(String label, String value) => GestureDetector(
    onTap: () => setState(() => _filter = value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _filter == value ? AppTheme.accent.withOpacity(0.15) : AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _filter == value ? AppTheme.accent : AppTheme.border),
      ),
      child: Text(label, style: TextStyle(
        color: _filter == value ? AppTheme.accent : AppTheme.text2,
        fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );

  void _showAddTicket() {
    final routerCtrl   = TextEditingController();
    final titleCtrl    = TextEditingController();
    final descCtrl     = TextEditingController();
    String priority    = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎫 بلاغ جديد',
            style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(controller: routerCtrl,
            style: const TextStyle(color: AppTheme.text1),
            decoration: const InputDecoration(labelText: 'اسم الجهاز')),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl,
            style: const TextStyle(color: AppTheme.text1),
            decoration: const InputDecoration(labelText: 'عنوان البلاغ *')),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 3,
            style: const TextStyle(color: AppTheme.text1),
            decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (routerCtrl.text.isEmpty || titleCtrl.text.isEmpty) return;
              await ref.read(apiClientProvider).addTicket(
                routerCtrl.text.trim(), titleCtrl.text.trim(),
                descCtrl.text.trim(), priority);
              if (mounted) { Navigator.pop(ctx); _load(); }
            },
            child: const Text('إضافة البلاغ'),
          ),
        ]),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onClose;
  const _TicketCard({required this.ticket, required this.onClose});

  static const _pc = {
    'critical': AppTheme.red,
    'high': Color(0xFFF97316),
    'medium': AppTheme.yellow,
    'low': AppTheme.green,
  };

  @override
  Widget build(BuildContext context) {
    final isOpen = ticket['status'] == 'open';
    final pc = _pc[ticket['priority'] as String? ?? 'medium'] ?? AppTheme.text2;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        border: Border(
          top: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: pc, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(ticket['title'] as String? ?? '',
              style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.w700))),
            if (isOpen)
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                  ),
                  child: const Text('✓ إغلاق',
                    style: TextStyle(color: AppTheme.green, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('📡 ${ticket['router']}  •  ${ticket['created_at'] ?? ''}',
            style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
          if ((ticket['desc'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(ticket['desc'] as String,
              style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}
