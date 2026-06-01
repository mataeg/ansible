import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

// ── Router Model ──────────────────────────────────────────────────────────────
class RouterDevice {
  final String name;
  final String ip;
  final String model;
  final String version;
  final bool   isOnline;
  final double? latency;

  const RouterDevice({
    required this.name,
    required this.ip,
    this.model   = '',
    this.version = '',
    this.isOnline = false,
    this.latency,
  });

  factory RouterDevice.fromJson(Map<String, dynamic> json, {bool? online, double? lat}) {
    return RouterDevice(
      name:     json['name']    ?? '',
      ip:       json['ip']      ?? '',
      model:    json['model']   ?? '',
      version:  json['version'] ?? '',
      isOnline: online ?? false,
      latency:  lat,
    );
  }
}

// ── Fleet State ───────────────────────────────────────────────────────────────
class FleetState {
  final List<RouterDevice> routers;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdate;

  const FleetState({
    this.routers    = const [],
    this.isLoading  = false,
    this.error,
    this.lastUpdate,
  });

  int get onlineCount   => routers.where((r) => r.isOnline).length;
  int get offlineCount  => routers.where((r) => !r.isOnline).length;
  int get total         => routers.length;

  FleetState copyWith({
    List<RouterDevice>? routers,
    bool?               isLoading,
    String?             error,
    DateTime?           lastUpdate,
  }) => FleetState(
    routers:    routers    ?? this.routers,
    isLoading:  isLoading  ?? this.isLoading,
    error:      error,
    lastUpdate: lastUpdate ?? this.lastUpdate,
  );
}

// ── Fleet Notifier ────────────────────────────────────────────────────────────
class FleetNotifier extends StateNotifier<FleetState> {
  final ApiClient _api;
  FleetNotifier(this._api) : super(const FleetState());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final liveData    = await _api.getLiveStatus();
      final routersData = await _api.getRouters();

      final liveList    = (liveData['live']    as List?)?.cast<String>() ?? [];
      final latencyMap  = (liveData['latency'] as Map?)?.cast<String, dynamic>() ?? {};
      final routersList = (routersData['routers'] as List?) ?? [];

      final routers = routersList.map((r) {
        final name = r['name'] as String;
        return RouterDevice.fromJson(
          r as Map<String, dynamic>,
          online: liveList.contains(name),
          lat: (latencyMap[name] as num?)?.toDouble(),
        );
      }).toList();

      // Sort: online first
      routers.sort((a, b) {
        if (a.isOnline == b.isOnline) return a.name.compareTo(b.name);
        return a.isOnline ? -1 : 1;
      });

      state = state.copyWith(
        routers:    routers,
        isLoading:  false,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>((ref) {
  return FleetNotifier(ref.read(apiClientProvider));
});

// ── SLA Provider ──────────────────────────────────────────────────────────────
final slaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(apiClientProvider).getSLA();
});

// ── Tickets Provider ──────────────────────────────────────────────────────────
final ticketsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(apiClientProvider).getAllTickets();
});

// ── Compliance Provider ───────────────────────────────────────────────────────
final complianceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(apiClientProvider).getCompliance();
});
