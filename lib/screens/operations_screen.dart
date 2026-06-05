import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/fleet_provider.dart';
import '../providers/auth_provider.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  String _scope = 'all'; // 'all' or 'single'
  String? _targetDevice;

  // Execution state
  bool _executing = false;
  String _activeAction = '';
  List<String> _consoleLogs = [];
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAction(String actionKey, String arabicTitle) async {
    setState(() {
      _executing = true;
      _activeAction = actionKey;
      _consoleLogs = ['▶ بدء إطلاق العملية: $arabicTitle...\n🎯 النطاق المستهدف: ${_scope == 'single' ? _targetDevice : 'كل الأسطول'}\n\n'];
    });

    try {
      final api = ref.read(apiClientProvider);
      final limit = _scope == 'single' ? _targetDevice : 'all';

      final streamResponse = await api.getStreamingResponse(
        '/run/$actionKey',
        queryParameters: {
          if (limit != null && limit != 'all') 'limit': limit,
        },
      );

      final stream = streamResponse.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!mounted) break;
        if (line.trim().isEmpty) continue;

        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '"__DONE__"' || dataStr == '__DONE__') {
            setState(() {
              _consoleLogs.add('\n✔ اكتملت العملية بنجاح!');
            });
            break;
          }

          try {
            final decoded = json.decode(dataStr) as String;
            setState(() {
              _consoleLogs.add(decoded);
            });
            // Auto-scroll
            Future.delayed(const Duration(milliseconds: 50), () {
              if (_scrollCtrl.hasClients) {
                _scrollCtrl.animateTo(
                  _scrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              }
            });
          } catch (_) {
            setState(() {
              _consoleLogs.add(dataStr);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _consoleLogs.add('\n❌ خطأ غير متوقع في الاتصال أو التنفيذ: $e');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _executing = false;
          _activeAction = '';
        });
      }
    }
  }

  Color _getLogColor(String line) {
    if (line.contains('failed=') && !line.contains('failed=0')) return AppTheme.red;
    if (line.contains('unreachable=') && !line.contains('unreachable=0')) return AppTheme.red;
    if (line.contains('changed=') && !line.contains('changed=0')) return AppTheme.yellow;
    if (line.toUpperCase().contains('FATAL') || line.toUpperCase().contains('FAILED') || line.toUpperCase().contains('ERROR')) {
      return AppTheme.red;
    }
    if (line.toUpperCase().contains('OK=') || line.contains('SUCCESS') || line.contains('✔')) {
      return AppTheme.green;
    }
    if (line.startsWith('TASK') || line.startsWith('PLAY')) {
      return AppTheme.accent;
    }
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);
    final routers = fleet.routers;
    final isAdmin = ref.watch(authProvider).isAdmin;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('🛡 التحكم والفحص الشامل'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scope card config
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_input_component, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'تحديد النطاق المستهدف للعمليات:',
                    style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('كل أجهزة الأسطول'),
                    selected: _scope == 'all',
                    selectedColor: AppTheme.accent.withOpacity(0.2),
                    labelStyle: TextStyle(color: _scope == 'all' ? AppTheme.accent : AppTheme.text2),
                    onSelected: (val) {
                      if (val) setState(() => _scope = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('راوتر محدد'),
                    selected: _scope == 'single',
                    selectedColor: AppTheme.accent.withOpacity(0.2),
                    labelStyle: TextStyle(color: _scope == 'single' ? AppTheme.accent : AppTheme.text2),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _scope = 'single';
                          if (_targetDevice == null && routers.isNotEmpty) {
                            _targetDevice = routers[0].name;
                          }
                        });
                      }
                    },
                  ),
                  if (_scope == 'single') ...[
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _targetDevice,
                      dropdownColor: AppTheme.card,
                      style: const TextStyle(color: AppTheme.text1),
                      items: routers.map<DropdownMenuItem<String>>((r) {
                        return DropdownMenuItem<String>(
                          value: r.name,
                          child: Text('${r.name} (${r.ip})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _targetDevice = val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pre-defined Actions Grid
            const Text('العمليات المتاحة للإطلاق الفوري:', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _operationCard(
                  key: 'audit_fleet',
                  title: 'فحص الامتثال والامتياز',
                  subtitle: 'تدقيق الأمان والـ Firewall وإيجاد الثغرات وتوليد التقارير بالشبكة',
                  icon: Icons.shield_outlined,
                  color: AppTheme.green,
                  onTap: () => _runAction('audit_fleet', 'فحص الامتثال والامتياز'),
                ),
                _operationCard(
                  key: 'sync',
                  title: 'مزامنة وتطبيق الإعدادات Golden State',
                  subtitle: 'مزامنة كاملة للإعدادات الموحدة والـ DNS والـ VPN والنطاقات',
                  icon: Icons.sync_problem,
                  color: AppTheme.accent,
                  onTap: () => _runAction('sync', 'مزامنة وتطبيق الإعدادات'),
                ),
                _operationCard(
                  key: 'reboot',
                  title: 'إعادة تشغيل الأجهزة',
                  subtitle: 'إرسال أمر إعادة تشغيل آمن وسريع للأجهزة المحددة بالشبكة',
                  icon: Icons.restart_alt_outlined,
                  color: Colors.orangeAccent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('⚠️ تأكيد إعادة التشغيل', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold)),
                        content: Text('هل أنت متأكد تماماً من رغبتك في إعادة تشغيل الأجهزة المستهدفة (${_scope == 'single' ? _targetDevice : 'كل الأسطول'})؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _runAction('reboot', 'إعادة تشغيل الأجهزة');
                            },
                            child: const Text('إعادة تشغيل الآن', style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                _operationCard(
                  key: 'discover_sstp',
                  title: 'مسح وإعداد ZTP للجدد',
                  subtitle: 'البحث وتفعيل الإعدادات المبدئية والتلقائية للأجهزة الجديدة المتصلة',
                  icon: Icons.wifi_find,
                  color: AppTheme.yellow,
                  onTap: () => _runAction('discover_sstp', 'مسح وإعداد ZTP للجدد'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Terminal Console
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF090D13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    // Terminal Titlebar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF161B22),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'Terminal logs & Ansible Real-time Outputs',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (!_executing && _consoleLogs.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppTheme.text2, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _consoleLogs = []),
                            )
                        ],
                      ),
                    ),
                    // Terminal Logs area
                    Expanded(
                      child: _consoleLogs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.terminal_outlined, size: 48, color: AppTheme.text2.withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  const Text('لا توجد عملية نشطة حالياً. قم بإطلاق عملية لعرض السجلات.', style: TextStyle(color: AppTheme.text2, fontSize: 11)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: _consoleLogs.length,
                              itemBuilder: (ctx, idx) {
                                final log = _consoleLogs[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      color: _getLogColor(log),
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationCard({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isThisRunning = _executing && _activeAction == key;

    return InkWell(
      onTap: _executing ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isThisRunning ? color : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: isThisRunning
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.text2, fontSize: 9, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
