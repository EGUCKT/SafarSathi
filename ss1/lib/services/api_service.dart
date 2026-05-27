// SafarSathi — API Service
// All HTTP calls to the FastAPI backend

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.255.63.232:8000'; // Real device on Wi-Fi
  // For Android emulator: use http://10.0.2.2:8000

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    // Auto-attach JWT token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post('/api/auth/register', data: {
      'name': name, 'phone': phone, 'password': password,
    });
    await _saveToken(res.data['access_token'], res.data['user_id'], name);
    return res.data;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post('/api/auth/login', data: {
      'phone': phone, 'password': password,
    });
    await _saveToken(res.data['access_token'], res.data['user_id'], res.data['name']);
    return res.data;
  }

  Future<void> _saveToken(String token, String userId, String name) async {
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'user_id',    value: userId);
    await _storage.write(key: 'user_name',  value: name);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ── Routes ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> findRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String preference = 'balanced',
  }) async {
    final res = await _dio.post('/api/routes/find', data: {
      'origin':      {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destLat,   'lng': destLng},
      'preference':  preference,
    });
    return res.data;
  }

  Future<List<dynamic>> findAlternativeRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final res = await _dio.post('/api/routes/alternatives', data: {
      'origin':      {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destLat,   'lng': destLng},
    });
    return res.data['routes'] as List;
  }

  Future<List<dynamic>> getNearbyHavens(double lat, double lng, {double radius = 1000}) async {
    final res = await _dio.get('/api/routes/safe-havens',
        queryParameters: {'lat': lat, 'lng': lng, 'radius_m': radius});
    return res.data['safe_havens'] as List;
  }

  Future<Map<String, dynamic>> startJourney({
    required double originLat, required double originLng,
    required double destLat,   required double destLng,
    required String routeId,
  }) async {
    final res = await _dio.post('/api/routes/journey/start', data: {
      'origin':      {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destLat,   'lng': destLng},
      'route_id':    routeId,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> pingLocation({
    required String journeyId,
    required double lat,
    required double lng,
  }) async {
    final res = await _dio.post('/api/routes/journey/ping', data: {
      'journey_id': journeyId,
      'lat':        lat,
      'lng':        lng,
    });
    return res.data;
  }

  Future<void> endJourney(String journeyId) async {
    await _dio.post('/api/routes/journey/end',
        queryParameters: {'journey_id': journeyId});
  }

  // ── SOS ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> triggerSOS({
    required double lat,
    required double lng,
    String triggerType = 'manual_button',
  }) async {
    final res = await _dio.post('/api/sos/trigger', data: {
      'lat':          lat,
      'lng':          lng,
      'trigger_type': triggerType,
    });
    return res.data;
  }

  Future<void> resolveSOS(String sosId) async {
    await _dio.post('/api/sos/resolve/$sosId');
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  Future<void> submitReport({
    required String reportType,
    required double lat,
    required double lng,
    String? description,
  }) async {
    await _dio.post('/api/reports/', data: {
      'report_type': reportType,
      'lat':         lat,
      'lng':         lng,
      'description': description,
    });
  }

  Future<List<dynamic>> getNearbyReports(double lat, double lng) async {
    final res = await _dio.get('/api/reports/nearby',
        queryParameters: {'lat': lat, 'lng': lng, 'radius_m': 500});
    return res.data['reports'] as List;
  }

  // ── Emergency contacts ───────────────────────────────────────────────────────

  Future<List<dynamic>> getContacts() async {
    final res = await _dio.get('/api/auth/contacts');
    return res.data as List;
  }

  Future<void> addContact({
    required String name,
    required String phone,
    String? relation,
  }) async {
    await _dio.post('/api/auth/contacts', data: {
      'name': name, 'phone': phone, 'relation': relation,
    });
  }

  Future<void> deleteContact(String contactId) async {
    await _dio.delete('/api/auth/contacts/$contactId');
  }

  // ── Admin/Stats ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAreaStats() async {
    final res = await _dio.get('/api/admin/area-stats');
    return res.data['areas'] as List;
  }
}

// Singleton
final api = ApiService();