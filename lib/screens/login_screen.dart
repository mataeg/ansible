import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../core/api_client.dart';
import '../core/router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _urlCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _showUrl  = false;

  static const String appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = ref.read(serverUrlProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final data = await ref.read(apiClientProvider).checkAppVersion();
      if (data['ok'] == true) {
        final latestVersion = data['version'] as String;
        final downloadUrl = data['download_url'] as String;
        if (latestVersion != appVersion && mounted) {
          _showUpdateDialog(latestVersion, downloadUrl);
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                'تحديث جديد متاح!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.text1,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يتوفر إصدار جديد من التطبيق ($version). يُرجى التحديث للحصول على آخر الميزات والتحسينات والاستقرار.',
                style: const TextStyle(color: AppTheme.text2, fontSize: 14, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً', style: TextStyle(color: AppTheme.text2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showDownloadInstructions(url);
              },
              child: const Text('تنزيل الآن', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDownloadInstructions(String url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('رابط التنزيل المباشر',
              style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('بإمكانك نسخ الرابط التالي وتحميل التطبيق مباشرة من المتصفح:',
                  style: TextStyle(color: AppTheme.text2, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: AppTheme.text2)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_showUrl) {
      await saveServerUrl(ref, _urlCtrl.text.trim());
    }
    final ok = await ref.read(authProvider.notifier).login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xFF060D1A), Color(0xFF0D1423)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.router, color: AppTheme.accent, size: 40),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 24),

                  Text('EasyBill Fleet Manager',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.text1, fontSize: 22,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 6),
                  Text('تسجيل الدخول للوحة التحكم',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 36),

                  // Server URL toggle
                  GestureDetector(
                    onTap: () => setState(() => _showUrl = !_showUrl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_showUrl ? Icons.expand_less : Icons.settings,
                          color: AppTheme.text2, size: 16),
                        const SizedBox(width: 4),
                        Text('عنوان السيرفر',
                          style: const TextStyle(color: AppTheme.text2, fontSize: 12)),
                      ],
                    ),
                  ),

                  if (_showUrl) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlCtrl,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: AppTheme.text1, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://192.168.10.243:5000',
                        prefixIcon: Icon(Icons.dns_outlined, color: AppTheme.text2),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Username
                  TextField(
                    controller: _userCtrl,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.text2),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 14),

                  // Password
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: AppTheme.text1),
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.text2),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.text2),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  // Error message
                  if (auth.error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppTheme.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(auth.error!,
                          style: const TextStyle(color: AppTheme.red, fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Login Button
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
                    child: auth.isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('دخول'),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 20),
                  Text('v1.0.0 — EasyBill Fleet',
                    style: const TextStyle(color: AppTheme.text2, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
