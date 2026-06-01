import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Server URL provider (configurable) ────────────────────────────────────────
final serverUrlProvider = StateProvider<String>((ref) => 'http://192.168.10.243:5000');

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
    return res.data as Map<String, dynamic>;
  }

  // ── SLA ─────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSLA() async {
    final res = await _dio.get('/api/sla');
    return res.data as Map<String, dynamic>;
  }

  // ── Device Profile ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDeviceInfo(String name) async {
    final res = await _dio.get('/api/device/$name/info');
    return res.data as Map<String, dynamic>;
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
    await _dio.post('/api/device/$name/notes/$noteId/delete');
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
