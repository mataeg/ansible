import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic> _settings = {};
  bool _loading    = true;
  bool _saving     = false;
  bool _wrEnabled  = false;
  bool _arEnabled  = false;
  bool _dryRun     = true;
  String _wrDay    = 'friday';
  int _wrHour      = 9;
  int _arInterval  = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).getAutomation();
      if (!mounted) return;
      final s = data['settings'] as Map<String, dynamic>? ?? {};
      final wr = s['weekly_report'] as Map? ?? {};
      final ar = s['auto_remediation'] as Map? ?? {};
      setState(() {
        _wrEnabled  = wr['enabled']        as bool? ?? false;
        _wrDay      = wr['day']            as String? ?? 'friday';
        _wrHour     = (wr['hour'] as num?)?.toInt() ?? 9;
        _arEnabled  = ar['enabled']        as bool? ?? false;
        _arInterval = (ar['interval_hours'] as num?)?.toInt() ?? 6;
        _dryRun     = ar['dry_run']        as bool? ?? true;
        _settings   = s;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_dryRun && _arEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('⚠️ تحذير', style: TextStyle(color: AppTheme.yellow)),
          content: const Text(
            'سيُشغّل الإصلاح التلقائي Ansible فعلياً على الراوترات!\nهل أنت متأكد؟',
            style: TextStyle(color: AppTheme.text1)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، أوافق'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).saveAutomation({
        'weekly_report':    {'enabled': _wrEnabled, 'day': _wrDay, 'hour': _wrHour},
        'auto_remediation': {'enabled': _arEnabled, 'interval_hours': _arInterval, 'dry_run': _dryRun},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ إعدادات الأتمتة')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendWeeklyReport() async {
    try {
      await ref.read(apiClientProvider).triggerWeeklyReport();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال التقرير عبر Telegram!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('⚙️ الإعدادات'),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User info
              _sectionCard('👤 معلومات المستخدم', [
                _infoRow('الاسم', auth.username),
                _infoRow('الدور', auth.role),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                ),
              ]),

              if (auth.isAdmin) ...[
                const SizedBox(height: 16),
                // Safety banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.yellow.withOpacity(0.25)),
                  ),
                  child: const Row(children: [
                    Text('⚠️', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'الأتمتة مُوقفة افتراضياً — فعّل بحذر. الـ Auto-Remediation في وضع DRY-RUN (تقرير فقط) حتى تغيّره يدوياً.',
                      style: TextStyle(color: AppTheme.yellow, fontSize: 11))),
                  ]),
                ),

                const SizedBox(height: 16),

                // Weekly Report
                _sectionCard('📅 التقرير الأسبوعي', [
                  Row(children: [
                    const Expanded(child: Text('تفعيل التقرير التلقائي',
                      style: TextStyle(color: AppTheme.text1))),
                    Switch(
                      value: _wrEnabled,
                      activeColor: AppTheme.green,
                      onChanged: (v) => setState(() => _wrEnabled = v),
                    ),
                  ]),
                  if (_wrEnabled) ...[
                    const SizedBox(height: 10),
                    _dropdownRow('اليوم', _wrDay, {
                      'friday': 'الجمعة', 'saturday': 'السبت',
                      'sunday': 'الأحد', 'monday': 'الإثنين',
                    }, (v) => setState(() => _wrDay = v!)),
                    const SizedBox(height: 8),
                    _dropdownRow('الوقت', '$_wrHour', {
                      '7': '07:00', '8': '08:00', '9': '09:00',
                      '10': '10:00', '12': '12:00 ظهراً',
                    }, (v) => setState(() => _wrHour = int.parse(v!))),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _sendWeeklyReport,
                    icon: const Icon(Icons.send_outlined, color: AppTheme.purple),
                    label: const Text('إرسال الآن (اختبار)',
                      style: TextStyle(color: AppTheme.purple)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.purple),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Auto-Remediation
                _sectionCard('🔧 الإصلاح التلقائي', [
                  Row(children: [
                    const Expanded(child: Text('تفعيل الإصلاح التلقائي',
                      style: TextStyle(color: AppTheme.text1))),
                    Switch(
                      value: _arEnabled,
                      activeColor: AppTheme.green,
                      onChanged: (v) => setState(() => _arEnabled = v),
                    ),
                  ]),
                  if (_arEnabled) ...[
                    const SizedBox(height: 8),
                    _dropdownRow('فترة الفحص', '$_arInterval', {
                      '2': 'كل 2 ساعة', '4': 'كل 4 ساعات',
                      '6': 'كل 6 ساعات', '12': 'كل 12 ساعة', '24': 'كل 24 ساعة',
                    }, (v) => setState(() => _arInterval = int.parse(v!))),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Checkbox(
                      value: _dryRun,
                      activeColor: AppTheme.accent,
                      onChanged: (v) => setState(() => _dryRun = v ?? true),
                    ),
                    const SizedBox(width: 6),
                    Text('وضع DRY-RUN (تقرير فقط — آمن)',
                      style: TextStyle(
                        color: _dryRun ? AppTheme.yellow : AppTheme.red, fontSize: 12)),
                  ]),
                  if (!_dryRun) Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🔴 تحذير: سيُنفّذ Ansible فعلياً على الراوترات!',
                      style: TextStyle(color: AppTheme.red, fontSize: 11)),
                  ),
                ]),

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                  label: const Text('حفظ الإعدادات'),
                ),
              ],
            ],
          ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
      const Divider(height: 16),
      ...children,
    ]),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
      const Spacer(),
      Text(value, style: const TextStyle(color: AppTheme.text1, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _dropdownRow(String label, String value, Map<String, String> opts, ValueChanged<String?> onChanged) =>
    Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
      const Spacer(),
      DropdownButton<String>(
        value: value,
        dropdownColor: AppTheme.card,
        style: const TextStyle(color: AppTheme.text1, fontSize: 12),
        underline: const SizedBox(),
        items: opts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    ]);
}
