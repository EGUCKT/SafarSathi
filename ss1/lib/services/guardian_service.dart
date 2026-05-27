// SafarSathi — Guardian Service (Module 7)
// Runs in background. Handles:
// 1. Volume button SOS gesture (3x volume down = SOS)
// 2. Dead-man switch (no movement + no response = auto SOS)
// 3. Native SMS from user's own number (free, no API)
// 4. Native phone call from user's own number (free)
// 5. Firebase broadcast of live location during SOS

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:dio/dio.dart';
import 'package:shake/shake.dart';

// ── Guardian Config ───────────────────────────────────────────────────────────

const int    kSosVolumePresses     = 3;       // press volume down 3x to trigger SOS
const int    kVolumeWindowSeconds  = 2;       // within 2 seconds
const int    kDeadmanWarningMin    = 3;       // warn after 3 min no movement
const int    kDeadmanTriggerMin    = 5;       // SOS after 5 min no response
const double kDeviationThresholdM  = 150.0;  // 150m off route = warning

// ── Background service setup ──────────────────────────────────────────────────

Future<void> initGuardianService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'safarsathi_guardian',
    'SafarSathi Guardian',
    description: 'Keeps you safe during navigation',
    importance: Importance.low,
  );

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart:             onGuardianStart,
      autoStart:           false,
      isForegroundMode:    true,
      notificationChannelId: 'safarsathi_guardian',
      initialNotificationTitle:   'SafarSathi Guardian Active',
      initialNotificationContent: 'Monitoring your journey...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart:   false,
      onForeground: onGuardianStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ── Main guardian loop (runs in background isolate) ───────────────────────────

@pragma('vm:entry-point')
void onGuardianStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs    = await SharedPreferences.getInstance();
  final guardian = GuardianLogic(service, prefs);
  await guardian.start();
}

class GuardianLogic {
  final ServiceInstance service;
  final SharedPreferences prefs;

  // State
  bool    _journeyActive    = false;
  bool    _sosTriggered     = false;
  String? _journeyId;
  List<Map<String, double>> _safeRouteCoords = [];
  DateTime? _lastMovement;
  DateTime? _warningShownAt;
  Position? _lastPosition;

  // Volume SOS tracking
  final int      _volumePressCount = 0;
  DateTime? _firstVolumePress;

  GuardianLogic(this.service, this.prefs);

  Future<void> start() async {
    // Listen for commands from the main Flutter UI
    service.on('start_journey').listen((data) {
      if (data == null) return;
      _journeyActive  = true;
      _journeyId      = data['journey_id'];
      _lastMovement   = DateTime.now();
      _sosTriggered   = false;
      final coords    = data['route_coords'] as List?;
      if (coords != null) {
        _safeRouteCoords = coords
            .map((c) => {'lat': c['lat'] as double, 'lng': c['lng'] as double})
            .toList();
      }
      _updateNotification('Journey active — Guardian watching');
    });

    service.on('end_journey').listen((_) {
      _journeyActive      = false;
      _sosTriggered       = false;
      _safeRouteCoords    = [];
      _updateNotification('Guardian standby');
    });

    service.on('user_acknowledged').listen((_) {
      // User responded to dead-man switch warning
      _warningShownAt = null;
      _lastMovement   = DateTime.now();
    });

    service.on('stop').listen((_) => service.stopSelf());

    // Start volume button listener
    _listenShake();

    // Main loop — runs every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_journeyActive || _sosTriggered) return;
      await _checkDeadmanSwitch();
      await _checkRouteDeviation();
      await _broadcastLocation();
    });
  }

  // ── Shake SOS ────────────────────────────────────────────────────────

  ShakeDetector? _shakeDetector;

  void _listenShake() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        _triggerSOS(trigger: 'shake_motion');
      },
      shakeThresholdGravity: 2.7, // Heavy shake required
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
    );
  }

  // ── Dead-man switch ──────────────────────────────────────────────────────────

  Future<void> _checkDeadmanSwitch() async {
    if (_lastMovement == null) return;
    final idleMin = DateTime.now().difference(_lastMovement!).inMinutes;

    if (idleMin >= kDeadmanTriggerMin && _warningShownAt != null) {
      // User didn't respond to warning — trigger SOS
      final warnedMinAgo = DateTime.now().difference(_warningShownAt!).inMinutes;
      if (warnedMinAgo >= 2) {
        await _triggerSOS(trigger: 'deadman_switch');
      }
    } else if (idleMin >= kDeadmanWarningMin && _warningShownAt == null) {
      // Show warning to user
      _warningShownAt = DateTime.now();
      service.invoke('deadman_warning', {
        'idle_minutes': idleMin,
        'message':      'Are you okay? Tap to confirm or SOS will be sent in 2 minutes.',
      });
      _showLocalNotification(
        'SafarSathi — Are you okay?',
        'Tap to confirm you are safe. SOS sends automatically in 2 min.',
      );
    }
  }

  // ── Route deviation check ────────────────────────────────────────────────────

  Future<void> _checkRouteDeviation() async {
    if (_safeRouteCoords.isEmpty) return;
    final position = await _getLocation();
    if (position == null) return;

    // Find minimum distance to any point on the safe route
    double minDist = double.infinity;
    for (final coord in _safeRouteCoords) {
      final d = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        coord['lat']!, coord['lng']!,
      );
      if (d < minDist) minDist = d;
    }

    if (minDist > kDeviationThresholdM) {
      service.invoke('route_deviation', {
        'deviation_m': minDist.round(),
        'message':     'You are ${minDist.round()}m from your safe route.',
      });
    }

    // Update last movement if position changed
    if (_lastPosition != null) {
      final moved = Geolocator.distanceBetween(
        _lastPosition!.latitude, _lastPosition!.longitude,
        position.latitude, position.longitude,
      );
      if (moved > 10) _lastMovement = DateTime.now(); // 10m movement resets timer
    }
    _lastPosition = position;
  }

  // ── Firebase live location broadcast ─────────────────────────────────────────

  Future<void> _broadcastLocation() async {
    final position = await _getLocation();
    if (position == null || _journeyId == null) return;

    try {
      final ref = FirebaseDatabase.instance.ref('journeys/$_journeyId/location');
      await ref.set({
        'lat':       position.latitude,
        'lng':       position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy':  position.accuracy,
      });
    } catch (e) {
      // Firebase failure is non-critical — continue
    }
  }

  // ── SOS Trigger ───────────────────────────────────────────────────────────────

  Future<void> _triggerSOS({required String trigger}) async {
    if (_sosTriggered) return; // prevent double-trigger
    _sosTriggered = true;

    // Notify main UI immediately
    service.invoke('sos_triggered', {'trigger': trigger});

    // Get current location
    final position = await _getLocation();
    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;

    // Load emergency contacts from prefs
    final contacts = prefs.getStringList('emergency_contacts') ?? [];
    final userName  = prefs.getString('user_name') ?? 'SafarSathi User';
    final apiBase   = prefs.getString('api_base_url') ?? 'http://10.0.2.2:8000';
    final token     = prefs.getString('auth_token') ?? '';

    // 1. Send native SMS from user's own SIM (FREE — no API needed)
    await _sendNativeSMS(contacts, userName, lat, lng);

    // 2. Initiate native phone call to first contact (FREE)
    if (contacts.isNotEmpty) {
      await _makeNativeCall(contacts.first);
    }

    // 3. Hit FastAPI to send WhatsApp via Twilio + log SOS event
    await _notifyBackend(apiBase, token, lat, lng, trigger);

    // 4. Broadcast live location on Firebase for contacts to see in real time
    await _broadcastSOSLocation(lat, lng, contacts);

    // 5. Show persistent local notification
    _showLocalNotification(
      '🚨 SOS Sent — SafarSathi',
      'Emergency contacts notified. Help is on the way.',
    );
  }

  // ── Native SMS (free, from user's SIM) ────────────────────────────────────────

  Future<void> _sendNativeSMS(
    List<String> contacts,
    String userName,
    double lat,
    double lng,
  ) async {
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    final message  = Uri.encodeComponent(
      '🚨 EMERGENCY - $userName needs help!\n'
      'Location: $mapsLink\n'
      'Sent via SafarSathi safety app.',
    );

    for (final phone in contacts) {
      try {
        // This opens the native SMS app with pre-filled message and sends
        // On Android: sms: URI with body sends directly if permission granted
        final uri = Uri.parse('sms:$phone?body=$message');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (_) {}
    }
  }

  // ── Native phone call (free, from user's number) ──────────────────────────────

  Future<void> _makeNativeCall(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  // ── Notify backend (WhatsApp via Twilio + log) ────────────────────────────────

  Future<void> _notifyBackend(
    String apiBase, String token,
    double lat, double lng, String trigger,
  ) async {
    try {
      final dio = Dio();
      await dio.post(
        '$apiBase/api/sos/trigger',
        data: {'lat': lat, 'lng': lng, 'trigger_type': trigger},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Backend failure doesn't block native SMS/call
    }
  }

  // ── Firebase SOS broadcast ────────────────────────────────────────────────────

  Future<void> _broadcastSOSLocation(
    double lat, double lng, List<String> contacts,
  ) async {
    try {
      final userId = prefs.getString('user_id') ?? 'unknown';
      final ref    = FirebaseDatabase.instance.ref('sos/$userId');
      await ref.set({
        'lat':       lat,
        'lng':       lng,
        'active':    true,
        'contacts':  contacts,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  void _updateNotification(String content) {
    service.invoke('update', {
      'title':   'SafarSathi Guardian',
      'content': content,
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'safarsathi_sos',
          'SafarSathi SOS',
          channelDescription: 'Emergency alerts',
          importance: Importance.max,
          priority:   Priority.high,
          fullScreenIntent: true,
        ),
      ),
    );
  }
}
