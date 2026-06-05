import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/fleet_provider.dart';

class MikrotikDashboardScreen extends ConsumerStatefulWidget {
  const MikrotikDashboardScreen({super.key});

  @override
  ConsumerState<MikrotikDashboardScreen> createState() => _MikrotikDashboardScreenState();
}

class _MikrotikDashboardScreenState extends ConsumerState<MikrotikDashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _verCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _verCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _showAddDeviceDialog() {
    _nameCtrl.clear();
    _verCtrl.text = '7.12';
    _modelCtrl.clear();
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
              title: const Row(
                children: [
                  Icon(Icons.add_to_photos_outlined, color: AppTheme.green),
                  SizedBox(width: 8),
                  Text('إضافة جهاز جديد للأسطول', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16)),
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
                          labelText: 'اسم الجهاز (مثل: router22)',
                          hintText: 'routerXX',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم الجهاز' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _verCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'إصدار RouterOS (مثل: 7.12)',
                          hintText: '7.X.X',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال إصدار نظام التشغيل' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _modelCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'موديل الجهاز (مثل: hAP ac2)',
                          hintText: 'hAP / hEX / CCR',
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
                        final res = await api.addDevice(name, ver, model);
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.green,
                              content: Text('✅ تم إضافة الجهاز $name بنجاح (IP: ${res['ip']})'),
                            ),
                          );
                          // Refresh the list of devices
                          ref.read(fleetProvider.notifier).refresh();
                        }
                      } catch (e) {
                        setDialogState(() => _submitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.red,
                              content: Text('❌ خطأ في الإضافة: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('إضافة', style: TextStyle(color: Colors.white)),
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
        title: const Text('📡 إدارة أجهزة المايكروتيك'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuTile(
            title: 'قائمة الأجهزة',
            subtitle: 'عرض وإدارة كل أجهزة الأسطول وحالتها ومواردها الحية',
            icon: Icons.router,
            color: AppTheme.accent,
            onTap: () => context.push('/mikrotik/devices'),
          ).animate().slideY(begin: 0.1, duration: 300.ms).fadeIn(),
          const SizedBox(height: 12),
          _menuTile(
            title: 'إضافة جهاز جديد',
            subtitle: 'إدخال جهاز جديد يدوياً إلى قائمة الأجهزة والأنسبل إنتفوري',
            icon: Icons.add_to_photos_outlined,
            color: AppTheme.green,
            onTap: _showAddDeviceDialog,
          ).animate().slideY(begin: 0.1, delay: 50.ms, duration: 300.ms).fadeIn(),
          const SizedBox(height: 12),
          _menuTile(
            title: 'اكتشاف الأجهزة (SSTP)',
            subtitle: 'البحث عن اتصالات SSTP/PPPoE النشطة على الراوتر الرئيسي وتثبيتها',
            icon: Icons.wifi_find_outlined,
            color: AppTheme.yellow,
            onTap: () => context.push('/mikrotik/discover'),
          ).animate().slideY(begin: 0.1, delay: 100.ms, duration: 300.ms).fadeIn(),
          const SizedBox(height: 12),
          _menuTile(
            title: 'قوالب Ansible للأتمتة',
            subtitle: 'استعراض وتحرير وتشغيل قوالب التشغيل (Playbooks) على الأجهزة والتحكم بالنطاق',
            icon: Icons.code,
            color: Colors.purpleAccent,
            onTap: () => context.push('/mikrotik/playbooks'),
          ).animate().slideY(begin: 0.1, delay: 150.ms, duration: 300.ms).fadeIn(),
          const SizedBox(height: 12),
          _menuTile(
            title: 'ملفات بوابة الهوتسبوت',
            subtitle: 'تعديل ونشر ملفات بوابات الهوتسبوت بالراوترات وعمل فحص ومصفوفة الامتثال',
            icon: Icons.folder_shared_outlined,
            color: Colors.orangeAccent,
            onTap: () => context.push('/mikrotik/hotspot-files'),
          ).animate().slideY(begin: 0.1, delay: 200.ms, duration: 300.ms).fadeIn(),
          const SizedBox(height: 12),
          _menuTile(
            title: 'التحكم والفحص الشامل',
            subtitle: 'مركز إطلاق عمليات الفحص الدوري وإصلاح وتهيئة الأجهزة وسحب السجلات الحية',
            icon: Icons.security,
            color: AppTheme.red,
            onTap: () => context.push('/mikrotik/operations'),
          ).animate().slideY(begin: 0.1, delay: 250.ms, duration: 300.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _menuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.text2, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.text2, size: 14),
          ],
        ),
      ),
    );
  }
}
