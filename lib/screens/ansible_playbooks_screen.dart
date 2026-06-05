import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/fleet_provider.dart';
import '../providers/auth_provider.dart';

class AnsiblePlaybooksScreen extends ConsumerStatefulWidget {
  const AnsiblePlaybooksScreen({super.key});

  @override
  ConsumerState<AnsiblePlaybooksScreen> createState() => _AnsiblePlaybooksScreenState();
}

class _AnsiblePlaybooksScreenState extends ConsumerState<AnsiblePlaybooksScreen> {
  List<dynamic> _templates = [];
  bool _loading = false;
  String? _error;

  dynamic _selectedTemplate;
  String _yamlContent = '';
  bool _loadingYaml = false;
  bool _editingYaml = false;
  final _yamlCtrl = TextEditingController();

  String _scope = 'all'; // 'all' or 'single'
  String? _targetDevice;

  // Execution state
  bool _executing = false;
  List<String> _consoleLogs = [];
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _yamlCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getTemplates();
      if (res['ok'] == true) {
        setState(() {
          _templates = res['templates'] as List? ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['error'] as String? ?? 'فشل تحميل القوالب';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الشبكة: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectTemplate(dynamic t) async {
    setState(() {
      _selectedTemplate = t;
      _yamlContent = '';
      _editingYaml = false;
      _loadingYaml = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getTemplateContent(t['path'] as String);
      if (res['ok'] == true) {
        setState(() {
          _yamlContent = res['content'] as String? ?? '';
          _yamlCtrl.text = _yamlContent;
          _loadingYaml = false;
        });
      } else {
        setState(() {
          _yamlContent = '❌ فشلت قراءة محتوى الملف: ${res['error']}';
          _loadingYaml = false;
        });
      }
    } catch (e) {
      setState(() {
        _yamlContent = '❌ خطأ أثناء الاتصال بالخادم: $e';
        _loadingYaml = false;
      });
    }
  }

  Future<void> _saveYaml() async {
    if (_selectedTemplate == null) return;
    setState(() => _loadingYaml = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.saveTemplateContent(
        _selectedTemplate['path'] as String,
        _yamlCtrl.text,
      );
      if (res['ok'] == true) {
        setState(() {
          _yamlContent = _yamlCtrl.text;
          _editingYaml = false;
          _loadingYaml = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.green, content: Text('✅ تم حفظ تعديلات القالب بنجاح!')),
        );
      } else {
        setState(() => _loadingYaml = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('❌ فشل الحفظ: ${res['error']}')),
        );
      }
    } catch (e) {
      setState(() => _loadingYaml = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.red, content: Text('❌ خطأ في الاتصال: $e')),
      );
    }
  }

  Future<void> _runPlaybook() async {
    if (_selectedTemplate == null) return;
    
    setState(() {
      _executing = true;
      _consoleLogs = ['▶ جاري التحضير لبدء تشغيل قالب الأتمتة على الأجهزة...\n'];
    });

    try {
      final api = ref.read(apiClientProvider);
      final path = _selectedTemplate['path'] as String;
      final limit = _scope == 'single' ? _targetDevice : 'all';

      final streamResponse = await api.getStreamingResponse(
        '/run/template',
        queryParameters: {
          'path': path,
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
              _consoleLogs.add('\n✔ اكتملت عملية الأتمتة بنجاح!');
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
          _consoleLogs.add('\n❌ خطأ غير متوقع في التدفق: $e');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _executing = false);
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
        title: const Text('📝 قوالب Ansible للأتمتة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchTemplates,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.red),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchTemplates,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidebar - Playbooks list
                    Container(
                      width: 250,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppTheme.border)),
                        color: Color(0xFF0F141C),
                      ),
                      child: ListView(
                        children: _groupPlaybooks().entries.map((entry) {
                          return ExpansionTile(
                            title: Text(
                              _getGroupArabicName(entry.key),
                              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            initiallyExpanded: true,
                            children: entry.value.map((t) {
                              final name = t['name'] as String;
                              final isSel = _selectedTemplate != null && _selectedTemplate['path'] == t['path'];
                              return ListTile(
                                dense: true,
                                selected: isSel,
                                selectedTileColor: AppTheme.accent.withOpacity(0.08),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: isSel ? AppTheme.accent : AppTheme.text1,
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11,
                                  ),
                                ),
                                subtitle: Text(
                                  t['desc'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.text2, fontSize: 9),
                                ),
                                onTap: () => _selectTemplate(t),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Main Area - Editor and execution panel
                    Expanded(
                      child: _selectedTemplate == null
                          ? const Center(
                              child: Text(
                                'اختر قالب أتمتة من القائمة الجانبية لعرضه وتشغيله',
                                style: TextStyle(color: AppTheme.text2),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header details
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📄 ${_selectedTemplate['name']}',
                                              style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'JetBrains Mono'),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedTemplate['desc'] as String? ?? '',
                                              style: const TextStyle(color: AppTheme.text2, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        if (!_editingYaml)
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                            label: const Text('تعديل القالب', style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                                            onPressed: () => setState(() => _editingYaml = true),
                                          )
                                        else
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () => setState(() {
                                                  _editingYaml = false;
                                                  _yamlCtrl.text = _yamlContent;
                                                }),
                                                child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.save, size: 16, color: Colors.white),
                                                label: const Text('حفظ', style: TextStyle(color: Colors.white)),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
                                                onPressed: _saveYaml,
                                              ),
                                            ],
                                          )
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Code Editor / View area
                                  Expanded(
                                    flex: 3,
                                    child: _loadingYaml
                                        ? const Center(child: CircularProgressIndicator())
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D1117),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: TextField(
                                              controller: _yamlCtrl,
                                              maxLines: null,
                                              expands: true,
                                              readOnly: !_editingYaml,
                                              style: const TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                fillColor: Colors.transparent,
                                                filled: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Configuration & Execution Panel
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('نطاق التشغيل: ', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(width: 12),
                                        ChoiceChip(
                                          label: const Text('كل الأسطول (All)'),
                                          selected: _scope == 'all',
                                          selectedColor: AppTheme.accent.withOpacity(0.25),
                                          labelStyle: TextStyle(color: _scope == 'all' ? AppTheme.accent : AppTheme.text2),
                                          onSelected: (val) {
                                            if (val) setState(() => _scope = 'all');
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('جهاز محدد (Single)'),
                                          selected: _scope == 'single',
                                          selectedColor: AppTheme.accent.withOpacity(0.25),
                                          labelStyle: TextStyle(color: _scope == 'single' ? AppTheme.accent : AppTheme.text2),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _scope = 'single';
                                                if (_targetDevice == null && routers.isNotEmpty) {
                                                  _targetDevice = routers[0]['name'] as String;
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
                                                value: r['name'] as String,
                                                child: Text('${r['name']} (${r['ip']})'),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setState(() => _targetDevice = val);
                                            },
                                          ),
                                        ],
                                        const Spacer(),
                                        ElevatedButton.icon(
                                          icon: _executing
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                              : const Icon(Icons.play_arrow, color: Colors.black),
                                          label: Text(_executing ? 'جاري التشغيل...' : 'إطلاق الأتمتة ZTP', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.accent,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _executing ? null : _runPlaybook,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Terminal Output Panel (if logs are present)
                                  if (_consoleLogs.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF090D13),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            // Terminal Titlebar
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF161B22),
                                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.terminal, color: Colors.redAccent, size: 16),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Ansible Live Output Console',
                                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold),
                                                  ),
                                                  const Spacer(),
                                                  if (!_executing)
                                                    IconButton(
                                                      icon: const Icon(Icons.close, color: AppTheme.text2, size: 14),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => setState(() => _consoleLogs = []),
                                                    )
                                                ],
                                              ),
                                            ),
                                            // Terminal Logs
                                            Expanded(
                                              child: ListView.builder(
                                                controller: _scrollCtrl,
                                                padding: const EdgeInsets.all(12),
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
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Map<String, List<dynamic>> _groupPlaybooks() {
    final Map<String, List<dynamic>> grouped = {};
    for (final t in _templates) {
      final grp = t['group'] as String? ?? 'system';
      if (!grouped.containsKey(grp)) {
        grouped[grp] = [];
      }
      grouped[grp]!.add(t);
    }
    return grouped;
  }

  String _getGroupArabicName(String group) {
    switch (group) {
      case 'execute':
        return '🚀 تشغيل وتعديل (Execute)';
      case 'audit':
        return '🔍 فحص وتدقيق (Audit)';
      case 'atomic':
        return '🧱 تهيئة جزئية (Atomic)';
      case 'verify':
        return '🛡 تحقق وأمان (Verify)';
      case 'provisioning':
        return '📦 إمداد وتثبيت (Provisioning)';
      case 'system':
        return '⚙️ ملفات النظام (System)';
      default:
        return group;
    }
  }
}
