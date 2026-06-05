import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Server URL provider (configurable) ────────────────────────────────────────
final serverUrlProvider = StateProvider<String>((ref) => 'https://ansible.mataeg.com');

// ── Singleton cookie jar ───────────────────────────────────────────────────────
final _cookieJar = CookieJar();

// ── Dio instance provider ─────────────────────────────────────────────────────
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverUrlProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ));
  
  // Bypass SSL verification to support self-signed certificates or intermediate trust chain issues
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    },
  );

  dio.interceptors.add(CookieManager(_cookieJar));
  dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  return dio;
});

// ── API Client ─────────────────────────────────────────────────────────────────
class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  // ── Auth ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/api/login',
        data: {'username': username, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _dio.post('/api/logout');
  }

  // ── Fleet ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLiveStatus() async {
    final res = await _dio.get('/api/live_status');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRouters() async {
    final res = await _dio.get('/api/routers');
    if (res.data is List) {
      return {'routers': res.data};
    }
    return res.data as Map<String, dynamic>;
  }

  // ── SLA ─────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSLA() async {
    final res = await _dio.get('/api/sla');
    return res.data as Map<String, dynamic>;
  }

  // ── Device Profile ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDeviceInfo(String name) async {
    try {
      final res = await _dio.get('/api/device/$name/facts');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        return e.response!.data as Map<String, dynamic>;
      }
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> healthCheck(String name) async {
    final res = await _dio.get('/api/device/$name/healthcheck');
    return res.data as Map<String, dynamic>;
  }

  // ── Notes ───────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getNotes(String name) async {
    final res = await _dio.get('/api/device/$name/notes');
    return (res.data as Map)['notes'] as List;
  }

  Future<void> addNote(String name, String text) async {
    await _dio.post('/api/device/$name/notes/add', data: {'text': text});
  }

  Future<void> deleteNote(String name, int noteId) async {
    await _dio.post('/api/device/$name/notes/delete', data: {'id': noteId});
  }

  // ── User Administration ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUsers() async {
    final res = await _dio.get('/api/admin/users');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addUser(String username, String password, String fullname, String role) async {
    final res = await _dio.post('/api/admin/users/add', data: {
      'username': username,
      'password': password,
      'fullname': fullname,
      'role': role,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editUser(String username, {String? fullname, String? role, String? password}) async {
    final data = <String, dynamic>{'username': username};
    if (fullname != null) data['fullname'] = fullname;
    if (role != null) data['role'] = role;
    if (password != null) data['password'] = password;

    final res = await _dio.post('/api/admin/users/edit', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteUser(String username) async {
    final res = await _dio.post('/api/admin/users/delete', data: {'username': username});
    return res.data as Map<String, dynamic>;
  }

  // ── Tickets ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getAllTickets() async {
    final res = await _dio.get('/api/tickets/all');
    return (res.data as Map)['tickets'] as List;
  }

  Future<List<dynamic>> getDeviceTickets(String name) async {
    final res = await _dio.get('/api/device/$name/tickets');
    return (res.data as Map)['tickets'] as List;
  }

  Future<void> addTicket(String name, String title, String desc, String priority) async {
    await _dio.post('/api/device/$name/tickets/add',
        data: {'title': title, 'desc': desc, 'priority': priority});
  }

  Future<void> closeTicket(String name, int ticketId) async {
    await _dio.post('/api/device/$name/tickets/$ticketId/close');
  }

  // ── Compliance ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCompliance() async {
    final res = await _dio.get('/api/compliance');
    return res.data as Map<String, dynamic>;
  }

  // ── Search ──────────────────────────────────────────────────────────────────
  Future<List<dynamic>> searchNotes(String q) async {
    final res = await _dio.get('/api/search/notes', queryParameters: {'q': q});
    return (res.data as Map)['results'] as List;
  }

  // ── Automation ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAutomation() async {
    final res = await _dio.get('/api/automation/settings');
    return res.data as Map<String, dynamic>;
  }

  Future<void> saveAutomation(Map<String, dynamic> settings) async {
    await _dio.post('/api/automation/settings/save', data: settings);
  }

  Future<void> triggerWeeklyReport() async {
    await _dio.post('/api/automation/trigger/weekly');
  }

  Future<Map<String, dynamic>> triggerRemediation() async {
    final res = await _dio.post('/api/automation/trigger/remediation');
    return res.data as Map<String, dynamic>;
  }

  // ── Version Check & Crash Reporting ──────────────────────────────────────────
  Future<Map<String, dynamic>> checkAppVersion() async {
    final res = await _dio.get('/api/app/version');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addDevice(String name, String version, String model) async {
    final res = await _dio.post('/api/devices/add', data: {
      'name': name,
      'version': version,
      'model': model,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSstpDiscovery() async {
    final res = await _dio.get('/api/discover/sstp');
    return res.data as Map<String, dynamic>;
  }

  Future<void> reportAppLog({
    required String error,
    required String stack,
    required String username,
    Map<String, dynamic>? deviceInfo,
  }) async {
    await _dio.post('/api/app/logs/report', data: {
      'error': error,
      'stack': stack,
      'username': username,
      'device_info': deviceInfo ?? {},
    });
  }

  // ── Templates ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTemplates() async {
    final res = await _dio.get('/api/templates');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTemplateContent(String path) async {
    final res = await _dio.get('/api/templates/get', queryParameters: {'path': path});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveTemplateContent(String path, String content) async {
    final res = await _dio.post('/api/templates/save', data: {'path': path, 'content': content});
    return res.data as Map<String, dynamic>;
  }

  // ── Hotspot Portal Files ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getHotspotFiles() async {
    final res = await _dio.get('/api/hotspot/files');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHotspotFileContent(String filename) async {
    final res = await _dio.get('/api/hotspot/file/content', queryParameters: {'filename': filename});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveHotspotFileContent(String filename, String content) async {
    final res = await _dio.post('/api/hotspot/file/save', data: {'filename': filename, 'content': content});
    return res.data as Map<String, dynamic>;
  }

  // ── Streaming Responses (for Ansible SSE) ──────────────────────────────────
  Future<ResponseBody> getStreamingResponse(String path, {Map<String, dynamic>? queryParameters}) async {
    final res = await _dio.get<ResponseBody>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.stream),
    );
    return res.data!;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

// ── Load saved server URL on startup ──────────────────────────────────────────
Future<void> loadSavedServerUrl(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('server_url');
  if (saved != null && saved.isNotEmpty) {
    ref.read(serverUrlProvider.notifier).state = saved;
  }
}

Future<void> saveServerUrl(WidgetRef ref, String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('server_url', url);
  ref.read(serverUrlProvider.notifier).state = url;
}
