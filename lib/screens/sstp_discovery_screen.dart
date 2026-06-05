import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/fleet_provider.dart';

class SstpDiscoveryScreen extends ConsumerStatefulWidget {
  const SstpDiscoveryScreen({super.key});

  @override
  ConsumerState<SstpDiscoveryScreen> createState() => _SstpDiscoveryScreenState();
}

class _SstpDiscoveryScreenState extends ConsumerState<SstpDiscoveryScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _known = [];
  List<dynamic> _newConnections = [];
  bool _loading = false;
  String? _error;

  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _verCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _verCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getSstpDiscovery();
      if (mounted) {
        if (res['ok'] == true) {
          setState(() {
            _known = res['known'] as List? ?? [];
            _newConnections = res['new'] as List? ?? [];
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['error'] as String? ?? 'فشل الفحص';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ أثناء الاتصال بالخادم: $e';
          _loading = false;
        });
      }
    }
  }

  void _showRegisterDialog(String pppName) {
    _nameCtrl.text = pppName;
    _verCtrl.text = '7.12';
    _modelCtrl.text = 'hAP ac2';
    setState(() => _submitting = false);

    showDialog(
      context: context,
      barrierDismissible: !_submitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.app_registration, color: AppTheme.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('تسجيل جهاز $pppName', style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16))),
                ],
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'اسم الجهاز',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم الجهاز' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _verCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'إصدار RouterOS',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال إصدار نظام التشغيل' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _modelCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'موديل الجهاز',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submitting ? null : () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      setDialogState(() => _submitting = true);
                      try {
                        final name = _nameCtrl.text.trim();
                        final ver = _verCtrl.text.trim();
                        final model = _modelCtrl.text.trim();

                        final api = ref.read(apiClientProvider);
                        await api.addDevice(name, ver, model);
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.green,
                              content: Text('✅ تم تسجيل وتثبيت الجهاز $name بنجاح في الأسطول!'),
                            ),
                          );
                          // Refresh lists
                          ref.read(fleetProvider.notifier).refresh();
                          _scan();
                        }
                      } catch (e) {
                        setDialogState(() => _submitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.red,
                              content: Text('❌ خطأ في التسجيل: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('تسجيل الجهاز', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('🔍 اكتشاف اتصالات SSTP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.accent),
                  const SizedBox(height: 20),
                  const Text('جاري سحب اتصالات PPPoE/SSTP النشطة...', style: TextStyle(color: AppTheme.text1, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('الاتصال بالراوتر الرئيسي (95.1.1.1) عبر API', style: TextStyle(color: AppTheme.text2, fontSize: 11)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 50, color: AppTheme.red),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _scan,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                          child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.accent,
                      unselectedLabelColor: AppTheme.text2,
                      indicatorColor: AppTheme.accent,
                      tabs: [
                        Tab(text: 'أجهزة غير مسجلة (${_newConnections.length})'),
                        Tab(text: 'أجهزة مسجلة (${_known.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildNewList(),
                          _buildKnownList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildNewList() {
    if (_newConnections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 48, color: AppTheme.green.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('ممتاز! لا توجد أجهزة نشطة غير مسجلة بالأسطول', style: TextStyle(color: AppTheme.text2, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _newConnections.length,
      itemBuilder: (ctx, i) {
        final item = _newConnections[i] as Map<String, dynamic>;
        final pppName = item['ppp_name'] as String? ?? '—';
        final address = item['address'] as String? ?? '—';
        final uptime = item['uptime'] as String? ?? '—';
        final service = item['service'] as String? ?? 'SSTP';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.yellow.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.yellow.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.wifi_tethering, color: AppTheme.yellow, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pppName, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('IP: $address  •  Uptime: $uptime', style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('Service: $service', style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRegisterDialog(pppName),
                  child: const Text('تسجيل', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
        );
      },
    );
  }

  Widget _buildKnownList() {
    if (_known.isEmpty) {
      return const Center(
        child: Text('لا توجد أجهزة مسجلة نشطة حالياً', style: TextStyle(color: AppTheme.text2)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _known.length,
      itemBuilder: (ctx, i) {
        final item = _known[i] as Map<String, dynamic>;
        final pppName = item['ppp_name'] as String? ?? '—';
        final address = item['address'] as String? ?? '—';
        final uptime = item['uptime'] as String? ?? '—';
        final routerName = item['router_name'] as String? ?? '—';
        final ip = item['ip'] as String? ?? '—';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.green.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.verified, color: AppTheme.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(pppName, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('مسجل', style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('IP المسجل: $ip  •  IP الفعلي: $address', style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('Uptime: $uptime', style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
        );
      },
    );
  }
}
