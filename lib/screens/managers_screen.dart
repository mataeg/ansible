import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class ManagersScreen extends ConsumerStatefulWidget {
  const ManagersScreen({super.key});

  @override
  ConsumerState<ManagersScreen> createState() => _ManagersScreenState();
}

class _ManagersScreenState extends ConsumerState<ManagersScreen> {
  List<dynamic> _users = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getUsers();
      if (mounted) {
        if (res['ok'] == true) {
          setState(() {
            _users = res['users'] as List? ?? [];
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['error'] as String? ?? 'فشل تحميل قائمة المستخدمين';
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

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'technician';
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text('إضافة مستخدم جديد',
                      style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.text2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: userCtrl,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم (Username)',
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.text2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المستخدم' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Icon(Icons.lock_outline, color: AppTheme.text2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppTheme.surface,
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'الصلاحية / الدور',
                          prefixIcon: Icon(Icons.security, color: AppTheme.text2),
                        ),
                        style: const TextStyle(color: AppTheme.text1),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('مدير نظام (Admin)')),
                          DropdownMenuItem(value: 'technician', child: Text('فني دعم (Technician)')),
                          DropdownMenuItem(value: 'support', child: Text('موظف دعم (Support)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            setDialogState(() => submitting = true);
                            try {
                              final name = nameCtrl.text.trim();
                              final username = userCtrl.text.trim();
                              final password = passCtrl.text.trim();

                              final api = ref.read(apiClientProvider);
                              final res = await api.addUser(username, password, name, selectedRole);

                              if (mounted) {
                                if (res['ok'] == true) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.green,
                                      content: Text('✅ تم إضافة المستخدم $username بنجاح!'),
                                    ),
                                  );
                                  _fetchUsers();
                                } else {
                                  setDialogState(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.red,
                                      content: Text('❌ خطأ: ${res['error'] ?? 'فشل إضافة المستخدم'}'),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => submitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.red,
                                    content: Text('❌ خطأ في الاتصال: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: submitting
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

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user['fullname']);
    final passCtrl = TextEditingController(); // Empty means no change
    String selectedRole = user['role'] ?? 'support';
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: AppTheme.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('تعديل المستخدم: ${user['username']}',
                        style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.text2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppTheme.text1),
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور الجديدة (اتركها فارغة لعدم التغيير)',
                          prefixIcon: Icon(Icons.lock_outline, color: AppTheme.text2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppTheme.surface,
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'الصلاحية / الدور',
                          prefixIcon: Icon(Icons.security, color: AppTheme.text2),
                        ),
                        style: const TextStyle(color: AppTheme.text1),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('مدير نظام (Admin)')),
                          DropdownMenuItem(value: 'technician', child: Text('فني دعم (Technician)')),
                          DropdownMenuItem(value: 'support', child: Text('موظف دعم (Support)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            setDialogState(() => submitting = true);
                            try {
                              final name = nameCtrl.text.trim();
                              final password = passCtrl.text.trim();

                              final api = ref.read(apiClientProvider);
                              final res = await api.editUser(
                                user['username'],
                                fullname: name,
                                role: selectedRole,
                                password: password.isNotEmpty ? password : null,
                              );

                              if (mounted) {
                                if (res['ok'] == true) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.green,
                                      content: Text('✅ تم تحديث بيانات ${user['username']} بنجاح!'),
                                    ),
                                  );
                                  _fetchUsers();
                                } else {
                                  setDialogState(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.red,
                                      content: Text('❌ خطأ: ${res['error'] ?? 'فشل تحديث البيانات'}'),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => submitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.red,
                                    content: Text('❌ خطأ في الاتصال: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('تحديث', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.red),
            SizedBox(width: 8),
            Text('تأكيد الحذف', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الحساب ($username) نهائياً من النظام؟',
            style: const TextStyle(color: AppTheme.text2, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              minimumSize: const Size(90, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.deleteUser(username);
        if (mounted) {
          if (res['ok'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.green,
                content: Text('✅ تم حذف الحساب $username بنجاح!'),
              ),
            );
            _fetchUsers();
          } else {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.red,
                content: Text('❌ خطأ: ${res['error'] ?? 'فشل حذف الحساب'}'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.red,
              content: Text('❌ خطأ في الاتصال: $e'),
            ),
          );
        }
      }
    }
  }

  String _getRoleArabic(String role) {
    switch (role) {
      case 'admin':
        return 'مدير نظام';
      case 'technician':
        return 'فني دعم';
      case 'support':
        return 'موظف دعم';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.purple;
      case 'technician':
        return AppTheme.accent;
      case 'support':
        return AppTheme.yellow;
      default:
        return AppTheme.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = ref.watch(authProvider).username;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('👥 إدارة المستخدمين والمديرين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
        label: const Text('مستخدم جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 50, color: AppTheme.red),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchUsers,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                          child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
                  ? const Center(
                      child: Text('لا يوجد مستخدمين مسجلين', style: TextStyle(color: AppTheme.text2)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _users.length,
                      itemBuilder: (ctx, i) {
                        final u = _users[i] as Map<String, dynamic>;
                        final username = u['username'] as String? ?? '';
                        final fullname = u['fullname'] as String? ?? '';
                        final role = u['role'] as String? ?? 'support';
                        final isMe = username == currentUsername;

                        final roleColor = _getRoleColor(role);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Avatar circle with role colors
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: roleColor.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Icon(
                                    role == 'admin'
                                        ? Icons.admin_panel_settings
                                        : role == 'technician'
                                            ? Icons.engineering
                                            : Icons.support_agent,
                                    color: roleColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // User information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              fullname,
                                              style: const TextStyle(
                                                  color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.green.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('أنت',
                                                  style: TextStyle(
                                                      color: AppTheme.green, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '@$username',
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(color: AppTheme.text2, fontSize: 11),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: roleColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: roleColor.withOpacity(0.2)),
                                            ),
                                            child: Text(
                                              _getRoleArabic(role),
                                              style: TextStyle(
                                                  color: roleColor, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppTheme.green, size: 20),
                                      onPressed: () => _showEditUserDialog(u),
                                      tooltip: 'تعديل البيانات',
                                    ),
                                    if (!isMe)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 20),
                                        onPressed: () => _deleteUser(username),
                                        tooltip: 'حذف الحساب',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: i * 30)),
                        );
                      },
                    ),
    );
  }
}
