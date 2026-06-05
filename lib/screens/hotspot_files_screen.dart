import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/api_client.dart';
import '../providers/fleet_provider.dart';
import '../providers/auth_provider.dart';

class HotspotFilesScreen extends ConsumerStatefulWidget {
  const HotspotFilesScreen({super.key});

  @override
  ConsumerState<HotspotFilesScreen> createState() => _HotspotFilesScreenState();
}

class _HotspotFilesScreenState extends ConsumerState<HotspotFilesScreen> {
  List<dynamic> _files = [];
  bool _loading = false;
  String? _error;

  String? _selectedFile;
  String _fileContent = '';
  bool _loadingContent = false;
  bool _editingContent = false;
  final _contentCtrl = TextEditingController();

  String _targetPath = 'flash/flash';
  String _scope = 'all'; // 'all' or 'single'
  String? _targetDevice;

  // Execution state
  bool _executing = false;
  List<String> _consoleLogs = [];
  final _scrollCtrl = ScrollController();

  // Compliance results
  final List<Map<String, dynamic>> _matrixData = [];

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getHotspotFiles();
      if (res['ok'] == true) {
        setState(() {
          _files = res['files'] as List? ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['error'] as String? ?? 'فشل تحميل الملفات';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectFile(String filename) async {
    setState(() {
      _selectedFile = filename;
      _fileContent = '';
      _editingContent = false;
      _loadingContent = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.getHotspotFileContent(filename);
      if (res['ok'] == true) {
        setState(() {
          _fileContent = res['content'] as String? ?? '';
          _contentCtrl.text = _fileContent;
          _loadingContent = false;
        });
      } else {
        setState(() {
          _fileContent = '❌ فشلت القراءة: ${res['error']}';
          _loadingContent = false;
        });
      }
    } catch (e) {
      setState(() {
        _fileContent = '❌ خطأ في الاتصال: $e';
        _loadingContent = false;
      });
    }
  }

  Future<void> _saveContent() async {
    if (_selectedFile == null) return;
    setState(() => _loadingContent = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.saveHotspotFileContent(
        _selectedFile!,
        _contentCtrl.text,
      );
      if (res['ok'] == true) {
        setState(() {
          _fileContent = _contentCtrl.text;
          _editingContent = false;
          _loadingContent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.green, content: Text('✅ تم حفظ التعديلات بنجاح على السيرفر!')),
        );
        _fetchFiles();
      } else {
        setState(() => _loadingContent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.red, content: Text('❌ فشل الحفظ: ${res['error']}')),
        );
      }
    } catch (e) {
      setState(() => _loadingContent = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.red, content: Text('❌ خطأ في الاتصال: $e')),
      );
    }
  }

  Future<void> _runAction(bool isAudit) async {
    setState(() {
      _executing = true;
      _consoleLogs = [
        isAudit
            ? '▶ بدء تشغيل عملية فحص ومطابقة ملفات الهوتسبوت...\n'
            : '▶ بدء عملية نشر وتحديث ملفات بوابة الهوتسبوت بالراوترات...\n'
      ];
      if (isAudit) {
        _matrixData.clear();
      }
    });

    try {
      final api = ref.read(apiClientProvider);
      final limit = _scope == 'single' ? _targetDevice : 'all';
      final endpoint = isAudit ? '/run/audit_hotspot_files' : '/run/deploy_hotspot_files';

      final streamResponse = await api.getStreamingResponse(
        endpoint,
        queryParameters: {
          'target_path': _targetPath,
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
              _consoleLogs.add(isAudit
                  ? '\n✔ اكتملت عملية فحص وجود الملفات بنجاح!'
                  : '\n✔ اكتملت عملية نشر وتثبيت بوابات الهوتسبوت بنجاح!');
            });
            break;
          }

          try {
            final decoded = json.decode(dataStr) as String;
            setState(() {
              _consoleLogs.add(decoded);
            });

            // Parse compliance results if printed in stdout
            if (isAudit && decoded.contains('RESULTS:')) {
              _parseResults(decoded);
            }

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

  void _parseResults(String logLine) {
    try {
      final rawJson = logLine.split('RESULTS:')[1].trim().replaceAll("'", '"');
      final results = json.decode(rawJson) as Map<String, dynamic>;

      // Extract host name from past logs
      String hostName = 'راوتر';
      for (int i = _consoleLogs.length - 1; i >= 0; i--) {
        if (_consoleLogs[i].contains('COMPLIANCE REPORT FOR:')) {
          hostName = _consoleLogs[i].split('COMPLIANCE REPORT FOR:')[1].trim();
          break;
        }
      }

      setState(() {
        _matrixData.add({
          'host': hostName,
          'path': _targetPath,
          'login': results['login_exists'],
          'status': results['status_exists'],
          'logout': results['logout_exists'],
          'error': results['error_exists'],
          'md5': results['md5_exists'],
        });
      });
    } catch (ex) {
      debugPrint('Error parsing compliance matrix JSON: $ex');
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
        title: const Text('📂 ملفات بوابة الهوتسبوت'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchFiles,
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
                        onPressed: _fetchFiles,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidebar - Local files list
                    Container(
                      width: 250,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppTheme.border)),
                        color: Color(0xFF0F141C),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'الملفات المتاحة بالسيرفر',
                              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const Divider(height: 1, color: AppTheme.border),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _files.length,
                              itemBuilder: (ctx, idx) {
                                final f = _files[idx] as Map<String, dynamic>;
                                final name = f['name'] as String;
                                final sizeKb = ((f['size'] as num? ?? 0) / 1024).toStringAsFixed(1);
                                final isSel = _selectedFile == name;

                                return ListTile(
                                  dense: true,
                                  selected: isSel,
                                  selectedTileColor: AppTheme.accent.withOpacity(0.08),
                                  leading: Icon(Icons.html, color: isSel ? AppTheme.accent : AppTheme.text2),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: isSel ? AppTheme.accent : AppTheme.text1,
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 12,
                                    ),
                                  ),
                                  subtitle: Text('$sizeKb KB', style: const TextStyle(color: AppTheme.text2, fontSize: 10)),
                                  onTap: () => _selectFile(name),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main Area
                    Expanded(
                      child: _selectedFile == null
                          ? const Center(
                              child: Text(
                                'اختر ملف بوابة هوتسبوت للتحرير أو النشر بالأسطول',
                                style: TextStyle(color: AppTheme.text2),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // File name and Edit action
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📄 /root/flash/flash/$_selectedFile',
                                              style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'JetBrains Mono'),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text('تعديل وحفظ الملف محلياً بالسيرفر قبل إطلاقه للراوترات', style: TextStyle(color: AppTheme.text2, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        if (!_editingContent)
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                            label: const Text('تعديل الملف', style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                                            onPressed: () => setState(() => _editingContent = true),
                                          )
                                        else
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () => setState(() {
                                                  _editingContent = false;
                                                  _contentCtrl.text = _fileContent;
                                                }),
                                                child: const Text('إلغاء', style: TextStyle(color: AppTheme.text2)),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.save, size: 16, color: Colors.white),
                                                label: const Text('حفظ محلي', style: TextStyle(color: Colors.white)),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
                                                onPressed: _saveContent,
                                              ),
                                            ],
                                          )
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // File Editor View
                                  Expanded(
                                    flex: 3,
                                    child: _loadingContent
                                        ? const Center(child: CircularProgressIndicator())
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D1117),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: TextField(
                                              controller: _contentCtrl,
                                              maxLines: null,
                                              expands: true,
                                              readOnly: !_editingContent,
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
                                  const SizedBox(height: 12),

                                  // target directory, scope, action buttons panel
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Wrap(
                                      spacing: 16,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        // target Directory Dropdown
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('المسار بالراوتر: ', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            DropdownButton<String>(
                                              value: _targetPath,
                                              dropdownColor: AppTheme.card,
                                              style: const TextStyle(color: AppTheme.text1, fontSize: 12, fontFamily: 'JetBrains Mono'),
                                              items: const [
                                                DropdownMenuItem(value: 'flash/flash', child: Text('flash/flash')),
                                                DropdownMenuItem(value: 'flash', child: Text('flash')),
                                                DropdownMenuItem(value: 'hotspot', child: Text('hotspot')),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) setState(() => _targetPath = val);
                                              },
                                            ),
                                          ],
                                        ),

                                        // Scope choice chips
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('النطاق: ', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            ChoiceChip(
                                              label: const Text('كل الأسطول', style: TextStyle(fontSize: 11)),
                                              selected: _scope == 'all',
                                              selectedColor: AppTheme.accent.withOpacity(0.2),
                                              labelStyle: TextStyle(color: _scope == 'all' ? AppTheme.accent : AppTheme.text2),
                                              onSelected: (val) => setState(() => _scope = 'all'),
                                            ),
                                            const SizedBox(width: 6),
                                            ChoiceChip(
                                              label: const Text('راوتر محدد', style: TextStyle(fontSize: 11)),
                                              selected: _scope == 'single',
                                              selectedColor: AppTheme.accent.withOpacity(0.2),
                                              labelStyle: TextStyle(color: _scope == 'single' ? AppTheme.accent : AppTheme.text2),
                                              onSelected: (val) {
                                                setState(() {
                                                  _scope = 'single';
                                                  if (_targetDevice == null && routers.isNotEmpty) {
                                                    _targetDevice = routers[0].name;
                                                  }
                                                });
                                              },
                                            ),
                                            if (_scope == 'single') ...[
                                              const SizedBox(width: 8),
                                              DropdownButton<String>(
                                                value: _targetDevice,
                                                dropdownColor: AppTheme.card,
                                                style: const TextStyle(color: AppTheme.text1, fontSize: 11),
                                                items: routers.map<DropdownMenuItem<String>>((r) {
                                                  return DropdownMenuItem<String>(
                                                    value: r.name,
                                                    child: Text(r.name),
                                                  );
                                                }).toList(),
                                                onChanged: (val) => setState(() => _targetDevice = val),
                                              ),
                                            ],
                                          ],
                                        ),

                                        // Actions Buttons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.security, size: 16, color: AppTheme.yellow),
                                              label: const Text('فحص وجود الملفات', style: TextStyle(color: AppTheme.yellow, fontSize: 12)),
                                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.yellow)),
                                              onPressed: _executing ? null : () => _runAction(true),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              icon: _executing
                                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                  : const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                                              label: const Text('نشر وتحديث البوابة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
                                              onPressed: _executing ? null : () => _runAction(false),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),

                                  // Compliance Matrix Card
                                  if (_matrixData.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            color: AppTheme.border.withOpacity(0.3),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.grid_on, color: AppTheme.accent, size: 16),
                                                SizedBox(width: 8),
                                                Text('مصفوفة مطابقة ملفات الهوتسبوت للشبكة (Compliance Matrix)', style: TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: DataTable(
                                              headingRowHeight: 32,
                                              dataRowMaxHeight: 32,
                                              dataRowMinHeight: 28,
                                              columns: const [
                                                DataColumn(label: Text('الراوتر', style: TextStyle(fontSize: 11, color: AppTheme.accent))),
                                                DataColumn(label: Text('المسار بالراوتر', style: TextStyle(fontSize: 11))),
                                                DataColumn(label: Text('login.html', style: TextStyle(fontSize: 11))),
                                                DataColumn(label: Text('status.html', style: TextStyle(fontSize: 11))),
                                                DataColumn(label: Text('logout.html', style: TextStyle(fontSize: 11))),
                                                DataColumn(label: Text('error.html', style: TextStyle(fontSize: 11))),
                                                DataColumn(label: Text('md5 verify', style: TextStyle(fontSize: 11))),
                                              ],
                                              rows: _matrixData.map((row) {
                                                final bool login = row['login'] == 'True' || row['login'] == true;
                                                final bool status = row['status'] == 'True' || row['status'] == true;
                                                final bool logout = row['logout'] == 'True' || row['logout'] == true;
                                                final bool error = row['error'] == 'True' || row['error'] == true;
                                                final bool md5 = row['md5'] == 'True' || row['md5'] == true;

                                                Widget icon(bool val) => val
                                                    ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: AppTheme.green, size: 14), SizedBox(width: 4), Text('متوفر', style: TextStyle(color: AppTheme.green, fontSize: 10))])
                                                    : const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cancel, color: AppTheme.red, size: 14), SizedBox(width: 4), Text('مفقود', style: TextStyle(color: AppTheme.red, fontSize: 10))]);

                                                return DataRow(cells: [
                                                  DataCell(Text(row['host'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                                  DataCell(Text(row['path'] as String, style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono'))),
                                                  DataCell(icon(login)),
                                                  DataCell(icon(status)),
                                                  DataCell(icon(logout)),
                                                  DataCell(icon(error)),
                                                  DataCell(icon(md5)),
                                                ]);
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Live Terminal Console
                                  if (_consoleLogs.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF090D13),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
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
                                                  const Icon(Icons.terminal, color: Colors.orangeAccent, size: 16),
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
}
