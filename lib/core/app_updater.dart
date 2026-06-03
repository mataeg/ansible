import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../core/app_theme.dart';

class AppUpdater {
  static Future<void> startUpdate(BuildContext context, String url, String targetVersion) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateDownloadDialog(url: url, version: targetVersion);
      },
    );
  }
}

class _UpdateDownloadDialog extends StatefulWidget {
  final String url;
  final String version;

  const _UpdateDownloadDialog({required this.url, required this.version});

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  double _progress = 0.0;
  String _downloadedText = "";
  String _statusText = "جاري تهيئة التحميل...";
  CancelToken? _cancelToken;
  bool _hasError = false;
  String _errorMsg = "";

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    _cancelToken = CancelToken();
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = "${tempDir.path}/app-update-${widget.version}.apk";

      final dio = Dio();
      // Configure SSL bypass for the downloader in local environments
      final adapter = dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        };
      }

      await dio.download(
        widget.url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              final currentMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _downloadedText = "$currentMb MB / $totalMb MB";
              _statusText = "جاري تحميل التحديث الجديد...";
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _statusText = "جاري فتح مثبت الحزمة للتحديث...";
        });
      }

      // Open the downloaded APK file
      final result = await OpenFilex.open(savePath);
      
      if (mounted) {
        if (result.type != ResultType.done) {
          setState(() {
            _hasError = true;
            _errorMsg = "فشل في فتح ملف APK: ${result.message}";
          });
        } else {
          Navigator.pop(context); // Close update downloader dialog
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = "خطأ أثناء التحميل: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _hasError ? 'خطأ في التحديث' : 'تنزيل التحديث الجديد',
        style: const TextStyle(color: AppTheme.text1, fontWeight: FontWeight.bold, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasError) ...[
            Text(_statusText, style: const TextStyle(color: AppTheme.text2, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${(_progress * 100).toInt()}%",
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  _downloadedText,
                  style: const TextStyle(color: AppTheme.text2, fontSize: 12),
                ),
              ],
            ),
          ] else ...[
            const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              style: const TextStyle(color: AppTheme.text1, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (!_hasError)
          TextButton(
            onPressed: () {
              _cancelToken?.cancel();
              Navigator.pop(context);
            },
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.red)),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: AppTheme.text2)),
          ),
      ],
    );
  }
}
