// SafarSathi — Complete App UI (Rebuilt from scratch)
// Single file for home + map + navigation
// Minimal liquid glass, smooth animations, works correctly
//
// Place this at: lib/screens/home_screen.dart
// Also update map_screen.dart to just re-export this

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:dio/dio.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GEOCODING (Nominatim, free)
// ─────────────────────────────────────────────────────────────────────────────

class _Place {
  final String label;
  final double lat, lng;
  _Place(this.label, this.lat, this.lng);
}

class _POI {
  final LatLng pos;
  final String type;
  _POI(this.pos, this.type);
}

Future<List<_Place>> _geocode(String q) async {
  if (q.trim().length < 2) return [];
  
  // Custom Fallback for local SDBCE College
  final sq = q.trim().toLowerCase();
  if (sq == 'sdbce' || sq.contains('sushila devi bansal')) {
    return [
      _Place('Sushila Devi Bansal College, Umaria, Mhow', 22.5972002399362, 75.78813343600413),
    ];
  }
  if (sq.contains('market') || sq.contains('bazar')) {
    return [
      _Place('Shyama Prasad Mukherji Bazar, Mhow', 22.5562, 75.7591),
      _Place('Main Street Market, Mhow Cantt', 22.5548, 75.7575),
      _Place('Cloth Market Mhow', 22.5555, 75.7582),
    ];
  }
  
  if (sq.contains('school') || sq.contains('college')) {
    return [
      _Place('St. Mary’s Higher Secondary School, Mhow', 22.5512, 75.7615),
      _Place('Rajeshwar Higher Secondary School, Mhow', 22.5495, 75.7630),
      _Place('Army Public School (APS) Mhow', 22.5621, 75.7482),
      _Place('Kendriya Vidyalaya Mhow', 22.5705, 75.7521),
      _Place('Vindhyachal Academy, Mhow', 22.5388, 75.7684),
    ];
  }

  // 1. Filtered Local Matches (Priority)
  final List<_Place> localSpots = [
    _Place('Mhow Railway Station (Dr. Ambedkar Nagar)', 22.5594, 75.7562),
    _Place('Mhow Civil Hospital, Dongargaon Road', 22.5582, 75.7531),
    _Place('Dreamland Cinema, Mhow', 22.5531, 75.7568),
    _Place('Infantry Museum Mhow (World’s Second)', 22.5505, 75.7512),
    _Place('Military College of Telecommunication Engineering (MCTE)', 22.5645, 75.7588),
    _Place('Veterinary College Mhow', 22.5442, 75.7655),
    _Place('Ambedkar Memorial (Janm Bhoomi)', 22.5688, 75.7455),
    _Place('Bercha Lake, Mhow', 22.5012, 75.7922),
    _Place('Patalpani Waterfall (Tourist Spot)', 22.5021, 75.7845),
    _Place('Heritage Train Point, Mhow Station', 22.5590, 75.7558),
    _Place('Gokul Hospital, Kishanganj', 22.5850, 75.7650),
    _Place('Kishanganj Police Station, AB Road', 22.5650, 75.7600),
    _Place('Mhow Cantonment Board Office', 22.5525, 75.7595),
    _Place('Colonel’s Academy, Mhow', 22.5415, 75.7725),
    _Place('Dusshera Maidan, Mhow', 22.5585, 75.7485),
    _Place('Swarg Mandir, Mhow', 22.5572, 75.7622),
    _Place('Christ Church Mhow', 22.5515, 75.7535),
    _Place('Mhow Fort Area', 22.5545, 75.7605),
    _Place('Hari Phatak, Mhow', 22.5568, 75.7492),
    _Place('Kodariya Village, Mhow', 22.5325, 75.7515),
    _Place('Bargunda Basti, Mhow', 22.5488, 75.7412),
    _Place('Sanghi Street, Mhow', 22.5552, 75.7572),
    _Place('Lalji Basti, Mhow', 22.5612, 75.7635),
    _Place('Gawli Palasia, Mhow-Indore Road', 22.5812, 75.7795),
    _Place('Sagar Cut Piece Center, Main Road', 22.5542, 75.7578),
    _Place('Bhanwarilal Mithaiwala, Kishanganj', 22.5849, 75.7768),
    _Place('The Grand Bhagwati (TGB), Mhow Road', 22.6015, 75.7945),
    _Place('Hotel Fun n Food, Mhow Road', 22.5925, 75.7842),
    _Place('Mhow Gaushala', 22.5712, 75.7682),
    _Place('Shanti Nagar Colony, Mhow', 22.5422, 75.7488),
    _Place('Adarsh Nagar, Mhow', 22.5385, 75.7552),
    _Place('Dongargaon Road, Mhow', 22.5615, 75.7415),
    _Place('Simrol Road Crossing, Mhow', 22.5492, 75.7688),
    _Place('Mall Road, Mhow Cantt', 22.5565, 75.7515),
    _Place('Post Office, Mhow Head Office', 22.5535, 75.7545),
    _Place('SBI Bank Mhow Branch', 22.5548, 75.7585),
    _Place('HDFC Bank, Main Street Mhow', 22.5558, 75.7572),
    _Place('Canara Bank, Mhow Road', 22.5625, 75.7612),
    _Place('V-Mart Mhow', 22.5575, 75.7598),
    _Place('Reliance Smart Point, Mhow', 22.5588, 75.7625),
    _Place('Mhow Gymkhana Club', 22.5518, 75.7495),
  ];

  final localMatches = localSpots.where((s) => s.label.toLowerCase().contains(sq)).toList();
  if (localMatches.isNotEmpty) return localMatches;

  // 2. Online Geocoding (Fallthrough if no local match)


  final dio = Dio();
  dio.options.receiveTimeout = const Duration(seconds: 4); // Fast failover

  // 1. RapidAPI Google Maps Places (Primary)
  try {
    final res = await dio.get(
      'https://google-map-places.p.rapidapi.com/maps/api/place/textsearch/json',
      queryParameters: {
        'query': q,
        'location': '22.7196,75.8577', // Bias to Indore/MP
        'radius': '50000', // 50km radius
      },
      options: Options(
        headers: {
          'x-rapidapi-key': '4321112245msh56b849760b1bf6cp115131jsnad8816797ef4',
          'x-rapidapi-host': 'google-map-places.p.rapidapi.com'
        }
      )
    );
    final results = res.data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      return results.take(8).map((e) {
        final loc = e['geometry']['location'];
        String name = e['name'] ?? '';
        String address = e['formatted_address'] ?? '';
        String label = name.isNotEmpty && address.isNotEmpty && !address.startsWith(name) 
            ? '$name, $address' 
            : address;
            
        return _Place(label, loc['lat'].toDouble(), loc['lng'].toDouble());
      }).toList();
    }
  } catch (_) {}

  // 2. LocationIQ (Fallback 1)
  try {
    final res = await dio.get(
      'https://us1.locationiq.com/v1/search.php',
      queryParameters: {
        'key': 'pk.29d4122fbba9038b21e9c3403fbc3a41',
        'q': q,
        'format': 'json',
        'limit': '8',
        'viewbox': '74.0,27.0,83.0,21.0', // Strict MP Bounds
        'bounded': '1',
      },
    );
    final data = res.data as List;
    if (data.isNotEmpty) {
      return data.map((e) => _Place(
        e['display_name'].toString().split(',').take(3).join(', '),
        double.parse(e['lat']), double.parse(e['lon'])
      )).toList();
    }
  } catch (_) {}

  // 3. ArcGIS (Fallback 2)
  try {
    final res = await dio.get(
      'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates',
      queryParameters: {
        'SingleLine': q,
        'f': 'json',
        'maxLocations': '8',
        'searchExtent': '74.0,21.0,83.0,27.0', // Strict MP Bounds
        'outFields': 'PlaceName,Place_addr,City,Region',
      },
    );
    final candidates = res.data['candidates'] as List;
    if (candidates.isNotEmpty) {
      return candidates.map((e) {
        final attrs = e['attributes'];
        final loc = e['location'];
        String title = attrs['PlaceName'] ?? attrs['Place_addr'] ?? e['address'];
        String context = '';
        if (attrs['City'] != null && attrs['City'].toString().isNotEmpty) context += attrs['City'];
        if (attrs['Region'] != null && attrs['Region'].toString().isNotEmpty && attrs['Region'] != attrs['City']) {
          context += (context.isEmpty ? '' : ', ') + attrs['Region'];
        }
        String fullLabel = context.isEmpty ? title : '$title, $context';
        return _Place(fullLabel, loc['y'], loc['x']);
      }).toList();
    }
  } catch (_) {}

  // 4. Photon (Fallback 3)
  try {
    final res = await dio.get(
      'https://photon.komoot.io/api/',
      queryParameters: {
        'q': q, 'limit': '8', 'lat': '22.7196', 'lon': '75.8577',
      },
    );
    final features = res.data['features'] as List;
    return features.map((e) {
      final p = e['properties'];
      final c = e['geometry']['coordinates'];
      String name = p['name'] ?? p['street'] ?? 'Unknown location';
      String label = name;
      if (p['city'] != null && !label.contains(p['city'])) label += ', ${p['city']}';
      if (p['state'] != null && !label.contains(p['state'])) label += ', ${p['state']}';
      return _Place(label, c[1], c[0]);
    }).toList();
  } catch (_) { return []; }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOME SCREEN  (map fullscreen + floating UI)
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  // Map
  final _mapCtrl = MapController();
  double _currentZoom = 15.0;
  double _currentRotation = 0.0;
  LatLng _myPos  = const LatLng(22.5560, 75.7640);
  StreamSubscription<Position>? _posStream;
  List<dynamic> _havens = [];
  List<dynamic> _reports = [];
  double _havenRadius = 200000; // 20km for map markers, but UI list will filter to 2km

  // Search state
  bool _searchOpen = false;
  final _fromCtrl  = TextEditingController();
  final _toCtrl    = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus   = FocusNode();
  _Place? _from, _to;
  List<_Place> _suggestions = [];
  bool _pickingFrom = true;
  Timer? _debounce;

  // Route state
  List<_RouteOption> _routes  = [];
  _RouteOption? _selected;
  bool _routing = false;
  String? _routeErr;
  bool _journeyActive = false;
  String? _journeyId;
  bool _routePanelMinimized = false;

  // Nav HUD & Compass
  String _navInstruction = "Head to route";
  IconData _navIcon = Icons.navigation_rounded;
  double _navDistance = 0.0;
  double? _heading;
  StreamSubscription<CompassEvent>? _compassStream;

  // POIs
  List<_POI> _pois = [];
  Timer? _poiDebounce;

  // SOS
  Timer? _sosTimer;
  double _sosProg = 0;
  bool   _sosHeld = false;

  // Ultimate Safety
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  Timer? _idleDeviationTimer;
  DateTime _lastMovedTime = DateTime.now();
  LatLng? _lastMovedPos;
  int _volumeDownCount = 0;
  Timer? _volumeResetTimer;
  bool _warningActive = false;
  Timer? _autoSosTimer;
  int _autoSosCountdown = 180;
  int _screamFrames = 0;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  // Animations
  late AnimationController _searchAnim;
  late Animation<double>   _searchExpand;

  @override
  void initState() {
    super.initState();
    _searchAnim   = AnimationController(vsync: this, duration: 320.ms);
    _searchExpand = CurvedAnimation(parent: _searchAnim, curve: Curves.easeInOutCubic);
    _startLocation();
    _initLocalNotifs();

    _compassStream = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) return;
      if (_heading == null) {
        setState(() => _heading = event.heading);
      } else {
        // Exponential Moving Average filter for smooth rotation
        double diff = event.heading! - _heading!;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        setState(() => _heading = (_heading! + diff * 0.15) % 360);
      }
    });
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _startLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return;

    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: 8.seconds);
      _updatePos(p);
    } catch (_) {}

    // Live stream for moving dot + dead-man pings
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10m
      ),
    ).listen((p) {
      _updatePos(p);
      if (_journeyActive && _journeyId != null) {
        api.pingLocation(journeyId: _journeyId!, lat: p.latitude, lng: p.longitude);
        _updateNavInstruction();
      }
    });

    _loadHavens();
  }

  void _updatePos(Position p) {
    if (!mounted) return;
    // HACKATHON DEMO: Override location to Mhow/Umariya area for testing
    setState(() => _myPos = LatLng(p.latitude, p.longitude)); // LatLng(p.latitude, p.longitude)
    _fetchPOIs();
  }

  Future<void> _fetchPOIs() async {
    final bounds = _mapCtrl.camera.visibleBounds;
    if (_mapCtrl.camera.zoom < 14) {
      if (_pois.isNotEmpty) setState(() => _pois.clear());
      return;
    }

    String query = """
      [out:json][timeout:10];
      (
        node["amenity"~"cafe|hospital|police|pharmacy|cinema|restaurant|bank"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        node["shop"~"mall|supermarket"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        node["religion"~"hindu|muslim|christian|sikh"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        node["tourism"~"hotel|resort|museum"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        node["highway"~"toll_gantry"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        node["railway"~"station"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
      );
      out body;
    """;
    
    try {
      final res = await Dio().post('https://overpass-api.de/api/interpreter', data: query);
      if (res.data != null && res.data['elements'] != null) {
        final List<_POI> newPois = [];
        for (var e in res.data['elements']) {
          if (e['lat'] != null && e['lon'] != null) {
            String type = 'unknown';
            if (e['tags'] != null) {
              if (e['tags']['amenity'] != null) type = e['tags']['amenity'];
              else if (e['tags']['shop'] != null) type = e['tags']['shop'];
              else if (e['tags']['religion'] != null) type = 'temple';
              else if (e['tags']['tourism'] != null) type = e['tags']['tourism'];
              else if (e['tags']['highway'] != null) type = e['tags']['highway'];
              else if (e['tags']['railway'] != null) type = e['tags']['railway'];
            }
            newPois.add(_POI(LatLng(e['lat'], e['lon']), type));
          }
        }
        if (mounted) setState(() => _pois = newPois);
      }
    } catch (e) {
      // Ignore POI errors to not interrupt user
    }
  }

  Future<void> _loadHavens() async {
    try {
      final h = await api.getNearbyHavens(_myPos.latitude, _myPos.longitude, radius: _havenRadius);
      final r = await api.getNearbyReports(_myPos.latitude, _myPos.longitude);
      
      // Fetch area stats for threshold-based permanent markers
      final a = await api.getAreaStats();
      final List<dynamic> crowdMarkers = a.where((area) => area['permanent_marker'] != null).map((area) {
        final pm = area['permanent_marker'];
        
        // Calculate distance for UI filtering later
        final dist = Geolocator.distanceBetween(
          _myPos.latitude, _myPos.longitude, 
          area['lat'], area['lng']
        );
        return {
          'id': area['id'],
          'name': pm['type'] == 'safe' ? '[GOOD LIGHTING] Verified Safety' : '[BAD LIGHTING] Caution Area',
          'place_type': pm['type'] == 'safe' ? 'lighting_good' : 'lighting_bad',
          'lat': area['lat'],
          'lng': area['lng'],
          'distance_m': dist.round(),
        };
      }).toList();

      if (mounted) setState(() { 
        _havens = [...h, ...crowdMarkers]; 
        _reports = r; 
      });
    } catch (_) {}
  }

  void _centerOnMe() {
    _mapCtrl.move(_myPos, 15);
    HapticFeedback.lightImpact();
  }

  void _animatedRotateToNorth() {
    final start = _mapCtrl.camera.rotation;
    if (start == 0.0) return;
    
    double end = 0.0;
    if (start > 180) end = 360.0; // Prevent the long way around
    
    final animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final anim = Tween<double>(begin: start, end: end).animate(CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic));
    
    anim.addListener(() {
      _mapCtrl.rotate(anim.value % 360.0);
    });
    
    animCtrl.forward().then((_) {
      _mapCtrl.rotate(0.0); // Ensure it snaps exactly to 0
      animCtrl.dispose();
    });
  }

  // ── Ultimate Safety ────────────────────────────────────────────────────────
  
  void _initLocalNotifs() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings darwinInit = DarwinInitializationSettings();
  
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
  );

  await _localNotifs.initialize(
    settings: initSettings, // The error says this must be named 'settings'
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Logic for when notification is tapped
    },
  );

  await _localNotifs
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

  Future<void> _startScreamDetection() async {
    if (await Permission.microphone.request().isGranted) {
      _noiseMeter = NoiseMeter();
      try {
        _noiseSubscription = _noiseMeter?.noise.listen((NoiseReading reading) {
          if (reading.maxDecibel > 85) {
            _screamFrames++;
            if (_screamFrames >= 4) { // 4 frames (~1s) of sustained 85+ dB (screaming)
              _triggerUltimateSOS("voice_trigger");
              _stopScreamDetection();
            }
          } else {
            _screamFrames = 0;
          }
        });
      } catch (err) {}
    }
  }

  void _stopScreamDetection() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _screamFrames = 0;
  }

  void _showDeviationWarning(String reason) {
    if (_warningActive) return;
    setState(() { _warningActive = true; _autoSosCountdown = 180; });
    
    // Show Local Notification
    _localNotifs.show(
      id: 0, 
      title: 'SafarSathi Alert', 
      body: '$reason Are you safe? SOS in 3 mins.',
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('ss_alerts', 'Alerts', importance: Importance.max, priority: Priority.high, fullScreenIntent: true))
    );

    // Show popup
    showDialog(context: context, barrierDismissible: false, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setDialogState) {
         if (_autoSosTimer == null || !_autoSosTimer!.isActive) {
           _autoSosTimer = Timer.periodic(const Duration(seconds: 1), (t) {
             if (!mounted) return;
             if (_autoSosCountdown <= 0) {
                t.cancel();
                Navigator.of(ctx).pop();
                _triggerUltimateSOS("deadman_switch");
             } else {
                setDialogState(() => _autoSosCountdown--);
             }
           });
         }
         
         return AlertDialog(
           backgroundColor: Colors.black87,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: const Text('🚨 Are you safe?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
           content: Text('$reason\n\nIf you do not respond, SOS will activate in $_autoSosCountdown seconds.', style: const TextStyle(color: Colors.white, fontSize: 16)),
           actions: [
             TextButton(
               onPressed: () {
                 _autoSosTimer?.cancel();
                 if (mounted) setState(() { _warningActive = false; _lastMovedTime = DateTime.now(); _lastMovedPos = _myPos; });
                 Navigator.of(ctx).pop();
               },
               child: const Text('I AM SAFE', style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
             ),
             TextButton(
               onPressed: () {
                 _autoSosTimer?.cancel();
                 Navigator.of(ctx).pop();
                 _triggerUltimateSOS("manual_button");
               },
               child: const Text('HELP (SOS)', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
             )
           ]
         );
      });
    });
  }

  void _triggerUltimateSOS(String triggerType) async {
    HapticFeedback.heavyImpact();
    _localNotifs.show(
      id: 1, 
      title: 'SOS ACTIVATED', 
      body: 'Alerts have been sent to your emergency contacts.',
      notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('ss_alerts', 'Alerts', importance: Importance.max, priority: Priority.high))
    );
      
    try {
      await api.triggerSOS(
        lat: _myPos.latitude, 
        lng: _myPos.longitude, 
        triggerType: triggerType
      );
      if (mounted) {
        setState(() { _warningActive = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('🚨 SOS Triggered! Alerts sent.', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    } catch (_) {}
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  void _openSearch() {
    setState(() { _searchOpen = true; _suggestions = []; });
    _searchAnim.forward();
    HapticFeedback.lightImpact();
    Future.delayed(200.ms, () => _fromFocus.requestFocus());
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    _searchAnim.reverse().then((_) {
      if (mounted) setState(() { _searchOpen = false; _suggestions = []; });
    });
  }

  void _onSearchCloseTap() {
    if (_toCtrl.text.isNotEmpty || _fromCtrl.text.isNotEmpty || _from != null || _to != null) {
      setState(() {
        _toCtrl.clear();
        _to = null;
        _fromCtrl.clear();
        _from = null;
        _routes = [];
        _selected = null;
        _routeErr = null;
        _suggestions = [];
        _routePanelMinimized = false;
      });
    } else {
      _closeSearch();
    }
  }

  void _onSearchType(String q, bool isFrom) {
    _debounce?.cancel();
    _debounce = Timer(350.ms, () async {
      final r = await _geocode(q);
      if (mounted) setState(() { _suggestions = r; _pickingFrom = isFrom; });
    });
  }

  void _pickSuggestion(_Place p) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_pickingFrom) {
        _from = p; _fromCtrl.text = p.label;
        FocusScope.of(context).requestFocus(_toFocus);
      } else {
        _to = p; _toCtrl.text = p.label;
        FocusScope.of(context).unfocus();
      }
      _suggestions = [];
    });
    if (_from != null && _to != null) {
      _closeSearch();
      _findRoutes();
    }
  }

  void _useMyLocation() {
    HapticFeedback.lightImpact();
    setState(() {
      _from = _Place('My Location', _myPos.latitude, _myPos.longitude);
      _fromCtrl.text = 'My Location';
      _suggestions   = [];
    });
    FocusScope.of(context).requestFocus(_toFocus);
  }

  // ── Routing ─────────────────────────────────────────────────────────────────

  Future<void> _findRoutes() async {
    if (_from == null || _to == null) return;
    setState(() { _routing = true; _routeErr = null; _routes = []; _selected = null; });

    // Pan map to midpoint
    _mapCtrl.move(
      LatLng((_from!.lat + _to!.lat) / 2, (_from!.lng + _to!.lng) / 2),
      11,
    );

    try {
      final data = await api.findAlternativeRoutes(
        originLat: _from!.lat, originLng: _from!.lng,
        destLat: _to!.lat, destLng: _to!.lng,
      );
      final routes = data.map<_RouteOption>((r) {
        final pts = (r['coordinates'] as List)
            .map<LatLng>((c) => LatLng(c['lat'] as double, c['lng'] as double))
            .toList();
        return _RouteOption(
          id:        r['route_id'] ?? '',
          pref:      r['preference'] ?? 'balanced',
          safety:    (r['overall_safety_score'] as num).toDouble(),
          distM:     (r['total_distance_m'] as num).toDouble(),
          walkMin:   r['walk_minutes'] as int,
          driveMin:  r['drive_minutes'] as int,
          label:     r['safety_label'] ?? '',
          coords:    pts,
          segments:  List<Map<String,dynamic>>.from(r['segments'] ?? []),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _routes  = routes;
          _selected = routes.isEmpty ? null : routes.first;
          _routing  = false;
          _routePanelMinimized = false;
        });
        if (_selected != null) _fitRoute(_selected!.coords);
      }
    } catch (e) {
      if (mounted) setState(() { _routing = false; _routeErr = 'Route not found — try locations within Mhow or Indore'; });
    }
  }

  void _fitRoute(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude,  maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);  maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude); maxLng = math.max(maxLng, p.longitude);
    }
    _mapCtrl.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 320),
    ));
  }

  Future<void> _startJourney() async {
    if (_selected == null || _from == null || _to == null) return;
    HapticFeedback.mediumImpact();
    try {
      final res = await api.startJourney(
        originLat: _from!.lat, originLng: _from!.lng,
        destLat:   _to!.lat,   destLng:   _to!.lng,
        routeId:   _selected!.id,
      );
      setState(() { 
        _journeyActive = true; 
        _journeyId = res['journey_id']; 
        _routePanelMinimized = true; // Auto-minimize when journey starts
      });
      WakelockPlus.enable(); // Keep CPU awake so shake works off-screen
      _lastMovedTime = DateTime.now();
      _lastMovedPos = _myPos;
      _startScreamDetection();
      
      _idleDeviationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
         if (_warningActive) return;
         const distance = Distance();
         
         // Idle check (moved < 15m in 5 mins)
         if (_lastMovedPos != null) {
           double movedDist = distance.as(LengthUnit.Meter, _lastMovedPos!, _myPos);
           if (movedDist < 15) {
              if (DateTime.now().difference(_lastMovedTime).inMinutes >= 5) {
                 _showDeviationWarning("You have been idle for 5 minutes.");
                 return;
              }
           } else {
              _lastMovedTime = DateTime.now();
              _lastMovedPos = _myPos;
           }
         }
         
         // Deviation check (off route by > 150m)
         if (_selected != null && _selected!.coords.isNotEmpty) {
            double minD = double.infinity;
            for (var p in _selected!.coords) {
               double d = distance.as(LengthUnit.Meter, _myPos, p);
               if (d < minD) minD = d;
            }
            if (minD > 150) {
               _showDeviationWarning("You have deviated from the safe route.");
            }
         }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Journey started — Guardian is watching')),
          ]),
          backgroundColor: const Color(0xFF30D158),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: 3.seconds,
        ));
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not start journey: $e'),
        behavior: SnackBarBehavior.floating,
      ));}
    }
  }

  Future<void> _endJourney() async {
    if (_journeyId == null) return;
    await api.endJourney(_journeyId!);
    _idleDeviationTimer?.cancel();
    _autoSosTimer?.cancel();
    _stopScreamDetection();
    _warningActive = false;
    WakelockPlus.disable();
    setState(() { _journeyActive = false; _journeyId = null; _routes = []; _selected = null; _from = null; _to = null; _fromCtrl.clear(); _toCtrl.clear(); _routePanelMinimized = false; });
    HapticFeedback.lightImpact();
  }

  void _updateNavInstruction() {
    if (_selected == null) return;
    final coords = _selected!.coords;
    if (coords.length < 2) return;

    int closestIdx = 0;
    double minD = double.infinity;
    const distance = Distance();
    
    for (int i = 0; i < coords.length - 1; i++) {
      double d = distance.as(LengthUnit.Meter, _myPos, coords[i]);
      if (d < minD) { minD = d; closestIdx = i; }
    }

    if (minD > 100) {
      setState(() { _navInstruction = "Return to route"; _navIcon = Icons.u_turn_left_rounded; _navDistance = minD; });
      return;
    }

    double distToTurn = 0.0;
    int turnIdx = closestIdx;
    
    for (int i = closestIdx; i < coords.length - 2; i++) {
      final p1 = coords[i];
      final p2 = coords[i+1];
      final p3 = coords[i+2];
      
      distToTurn += distance.as(LengthUnit.Meter, i == closestIdx ? _myPos : p1, p2);
      
      double b1 = distance.bearing(p1, p2);
      double b2 = distance.bearing(p2, p3);
      double diff = (b2 - b1) % 360;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      
      if (diff.abs() > 30) {
        turnIdx = i + 1;
        setState(() {
          if (diff > 30 && diff < 150) {
            _navInstruction = "Turn Right"; _navIcon = Icons.turn_right_rounded;
          } else if (diff < -30 && diff > -150) {
            _navInstruction = "Turn Left"; _navIcon = Icons.turn_left_rounded;
          } else {
            _navInstruction = "Make a U-Turn"; _navIcon = Icons.u_turn_left_rounded;
          }
          _navDistance = distToTurn;
        });
        return;
      }
    }
    
    if (turnIdx == closestIdx) {
      double d = distance.as(LengthUnit.Meter, _myPos, coords.last);
      setState(() { _navInstruction = "Destination ahead"; _navIcon = Icons.flag_rounded; _navDistance = d; });
    }
  }

  // ── SOS ─────────────────────────────────────────────────────────────────────

  Future<void> _sosStart() async {
    HapticFeedback.mediumImpact();
    setState(() { _sosHeld = true; _sosProg = 0; });
    _sosTimer = Timer.periodic(20.ms, (t) async {
      if (!mounted) { t.cancel(); return; }
      setState(() => _sosProg += 20 / 1000); // 1-second hold
      if (_sosProg >= 1) {
        t.cancel(); _sosProg = 0; _sosHeld = false;
        try {
          final c = await api.getContacts();
          if (c.isEmpty && mounted) {
            _showNoContact(); return;
          }
        } catch (_) {}
        HapticFeedback.heavyImpact();
        api.triggerSOS(lat: _myPos.latitude, lng: _myPos.longitude);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('🚨 SOS Triggered! Alerts sent to contacts.', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
        }
      }
    });
  }

  void _sosEnd() {
    _sosTimer?.cancel();
    if (mounted) setState(() { _sosHeld = false; _sosProg = 0; });
  }

  void _showNoContact() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('No Emergency Contacts'),
      content: const Text('Add at least one contact in Profile before using SOS.'),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }, child: const Text('Go to Profile')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    ));
  }

  // ── Sheets ───────────────────────────────────────────────────────────────────

  void _openReport() => showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(pos: _myPos),
  );

  void _openHavens() => showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => _HavensSheet(
        havens: _havens,
        radius: _havenRadius,
        onRadiusChange: (r) async {
          setSheetState(() => _havenRadius = r);
          setState(() => _havenRadius = r);
          final h = await api.getNearbyHavens(_myPos.latitude, _myPos.longitude, radius: r);
          if (mounted) {
            setState(() => _havens = h);
            setSheetState(() => _havens = h);
          }
        },
        onSelect: (h) => _startJourneyTo(h),
      )
    ),
  );

  void _showMarkerPopup(String title, String subtitle, IconData icon, Color color, double lat, double lng, {int? distance, bool showNavigate = true}) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GlassBox(
        radius: 26,
        surface: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(distance != null ? '$subtitle · ${distance}m' : subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ])),
            ]),
            if (showNavigate) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    // _startJourneyTo handles the pop internally, so we don't do it here
                    _startJourneyTo({'name': title, 'lat': lat, 'lng': lng});
                  },
                  child: const Text('Navigate Here', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _startJourneyTo(Map<String, dynamic> h) async {
    Navigator.pop(context); // close sheet
    final lat = h['lat'] as double?;
    final lng = h['lng'] as double?;
    if (lat == null || lng == null) return;
    
    setState(() {
      _from = _Place('My Location', _myPos.latitude, _myPos.longitude);
      _fromCtrl.text = 'My Location';
      _to = _Place(h['name'] ?? 'Safe Haven', lat, lng);
      _toCtrl.text = h['name'] ?? 'Safe Haven';
    });
    
    await _findRoutes();
    if (_selected != null) {
      await _startJourney();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(opacity: animation, child: page),
    transitionDuration: 250.ms,
  );

  String _dist(_RouteOption r) =>
      r.distM > 1000 ? '${(r.distM/1000).toStringAsFixed(1)} km' : '${r.distM.round()} m';

  String _time(_RouteOption r) =>
      r.driveMin < 60 ? '~${r.driveMin} min drive' : '~${(r.driveMin/60).toStringAsFixed(1)} hr drive';

  @override
  void dispose() {
    _idleDeviationTimer?.cancel();
    _autoSosTimer?.cancel();
    _volumeResetTimer?.cancel();
    _stopScreamDetection();
    _poiDebounce?.cancel();
    _compassStream?.cancel();
    _posStream?.cancel();
    _sosTimer?.cancel();
    _debounce?.cancel();
    _searchAnim.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  
  // Move this helper method outside of build() but inside your _HomeScreenState class
({IconData icon, Color color, String subtitle}) _getMarkerConfig(
    String name, String type) {
  final n = name.toUpperCase();

  // 0. Safety Zones (Heatmap Auras)
  if (n.contains('[CRIME ZONE]')) {
    return (icon: Icons.gpp_maybe_rounded, color: Colors.red, subtitle: 'High Alert Zone');
  }
  if (n.contains('[CAUTION ZONE]')) {
    return (icon: Icons.warning_amber_rounded, color: Colors.orange, subtitle: 'Caution Area');
  }
  if (n.contains('[SAFE ZONE]')) {
    return (icon: Icons.gpp_good_rounded, color: Colors.greenAccent[700]!, subtitle: 'Verified Safe Zone');
  }
  if (n.contains('[LIGHT ZONE]')) {
    return (icon: Icons.lightbulb_rounded, color: Colors.lightBlueAccent, subtitle: 'Well-Lit Zone');
  }
  if (n.contains('[DULL ZONE]')) {
    return (icon: Icons.lightbulb_outline, color: Colors.purpleAccent, subtitle: 'Dimly Lit Area');
  }

  // 1. Check Prefixes first (Your custom lighting/safety markers)
  if (n.contains('[BAD LIGHTING]') || n.contains('[POOR LIGHTING]')) {
    return (icon: Icons.lightbulb_outline, color: Colors.orange[800]!, subtitle: 'Poor Lighting Area');
  }
  if (n.contains('[GOOD LIGHTING]')) {
    return (icon: Icons.lightbulb, color: Colors.yellowAccent[700]!, subtitle: 'Good Lighting Area');
  }
  if (n.contains('[CCTV]')) {
    return (icon: Icons.videocam_rounded, color: Colors.blue, subtitle: 'CCTV Coverage');
  }
  if (n.contains('[CROWDED]')) {
    return (icon: Icons.groups_rounded, color: Colors.orange, subtitle: 'Crowded Area');
  }
  if (n.contains('[DESERTED]')) {
    return (icon: Icons.person_off_rounded, color: Colors.grey, subtitle: 'Deserted Area');
  }
  if (n.contains('[BLIND SPOT]')) {
    return (icon: Icons.visibility_off_rounded, color: Colors.red, subtitle: 'Blind Spot');
  }
  if (n.contains('[HARASSMENT]')) {
    return (icon: Icons.warning_amber_rounded, color: Colors.redAccent, subtitle: 'Harassment Prone');
  }
  if (n.contains('[CAFE]')) {
    return (icon: Icons.local_cafe_rounded, color: Colors.brown, subtitle: 'Cafe');
  }
  if (n.contains('[MALL]')) {
    return (icon: Icons.shopping_cart_rounded, color: Colors.brown, subtitle: 'Mall');
  }
  if (n.contains('[CINEMA]')) {
    return (icon: Icons.movie_rounded, color: Colors.brown, subtitle: 'Cinema');
  }
  if (n.contains('[STATION]')) {
    return (icon: Icons.train_rounded, color: Colors.brown, subtitle: 'Station');
  }
  if (n.contains('[BUS STOP]')) {
    return (icon: Icons.directions_bus_rounded, color: Colors.brown, subtitle: 'Bus Stop');
  }
  if (n.contains('[LANDMARK]')) {
    return (icon: Icons.place_rounded, color: Colors.brown, subtitle: 'Landmark');
  }
  if (n.contains('[TEMPLE]')) {
    return (icon: Icons.synagogue_rounded, color: Colors.deepOrange, subtitle: 'Temple');
  }

  // 2. Default to standard place types if no prefix is found
  return switch (type) {
    'police_station' => (icon: Icons.local_police_rounded, color: const Color(0xFF007AFF), subtitle: 'POLICE STATION'),
    'hospital'       => (icon: Icons.local_hospital_rounded, color: const Color(0xFFFF3B30), subtitle: 'HOSPITAL'),
    'pharmacy'       => (icon: Icons.medical_services_rounded, color: const Color(0xFF30D158), subtitle: 'PHARMACY'),
    'lighting_good'  => (icon: Icons.lightbulb_rounded, color: const Color(0xFFFFD60A), subtitle: 'CROWD-VERIFIED GOOD LIGHTING'),
    'lighting_bad'   => (icon: Icons.lightbulb_outline, color: const Color(0xFFFF9500), subtitle: 'CROWD-REPORTED POOR LIGHTING'),
    _                => (icon: Icons.shield_rounded, color: const Color(0xFF8E8E93), subtitle: type.replaceAll('_', ' ').toUpperCase()),
  };
}

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final colors  = Theme.of(context).extension<SafarSathiColors>()!;
    final surface = isDark ? const Color(0xCC0A0A0F) : const Color(0xCCFFFFFF);
    final border  = isDark ? const Color(0x18FFFFFF) : const Color(0x22000000);

    // Polylines
    final polylines = <Polyline>[];
    for (final r in _routes) {
      if (r == _selected && r.segments.isNotEmpty && r.segments.length >= r.coords.length - 1 && r.coords.length > 1) {
        // Draw colored segments
        for (int i = 0; i < r.segments.length; i++) {
          if (i + 1 >= r.coords.length) break;
          final seg = r.segments[i];
          final colorHex = seg['color'] as String? ?? '#888888';
          final c = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
          polylines.add(Polyline(
            points: [r.coords[i], r.coords[i+1]],
            color: c,
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ));
        }
      } else {
        // Draw solid line
        polylines.add(Polyline(
          points:      r.coords,
          color:       r == _selected ? r.color : Colors.grey.withAlpha(90),
          strokeWidth: r == _selected ? 5 : 3,
          strokeCap:   StrokeCap.round,
          strokeJoin:  StrokeJoin.round,
        ));
      }
    }

    final markers = <Marker>[];

    // 1. POIs (Only show if zoomed in, with fade)
    final fadeOpacity = (_currentZoom - 13.5).clamp(0.0, 1.0);
    final havenFadeOpacity = (_currentZoom - 11.5).clamp(0.0, 1.0);
    final zoneFadeOpacity = (_currentZoom - 11.0).clamp(0.0, 1.0); // Zones stay visible longer
    final showMinorMarkers = fadeOpacity > 0;
    final showZones = zoneFadeOpacity > 0;

    if (showMinorMarkers) {
      for (var p in _pois) {
        final config = switch(p.type) {
          'cafe' || 'restaurant' => (Icons.restaurant_rounded, Colors.orange),
          'hospital'             => (Icons.local_hospital_rounded, Colors.red),
          'police'               => (Icons.local_police_rounded, Colors.blue),
          'pharmacy'             => (Icons.local_pharmacy_rounded, Colors.green),
          'cinema'               => (Icons.movie_rounded, Colors.purple),
          'mall' || 'supermarket'=> (Icons.local_mall_rounded, Colors.teal),
          'temple'               => (Icons.account_balance_rounded, Colors.amber),
          'hotel' || 'resort'    => (Icons.hotel_rounded, Colors.indigo),
          'bank'                 => (Icons.account_balance_wallet_rounded, Colors.blueGrey),
          'station'              => (Icons.train_rounded, Colors.black87),
          _                      => (Icons.place_rounded, Colors.grey),
        };

        markers.add(Marker(
          point: p.pos, width: 32, height: 32,
          child: Opacity(
            opacity: fadeOpacity,
            child: Container(
              decoration: BoxDecoration(color: config.$2.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: config.$2.withOpacity(0.5))),
              child: Center(child: Icon(config.$1, color: config.$2, size: 18)),
            ),
          )
        ));
      }
    }

    // 2. Safe Haven Pins & Reference Points
    for (final h in _havens) {
      final lat = h['lat'] as double?; final lng = h['lng'] as double?;
      if (lat == null || lng == null) continue;

      final name = h['name']?.toString() ?? 'Safe Haven';
      final type = h['place_type']?.toString() ?? '';
      
      final isReferencePoint = name.contains('[') && name.contains(']');
      
      // Determine if this is a "Destinational" marker vs a "Status" marker
      final nUp = name.toUpperCase();
      final isStatusMarker = nUp.contains('LIGHTING') || 
                             nUp.contains('BLIND SPOT') || 
                             nUp.contains('HARASSMENT') || 
                             nUp.contains('DESERTED') || 
                             nUp.contains('CCTV');

      final isLighting   = nUp.contains('LIGHTING');
      final isHarassment = nUp.contains('HARASSMENT');
      final isZone       = nUp.contains('ZONE');
      
      // 2. Determine if navigation is appropriate
      bool canNavigate = !isStatusMarker;
      if (nUp.contains('DULL') || nUp.contains('DIM') || nUp.contains('CRIME') || 
          nUp.contains('THEFT') || nUp.contains('DANGER') || nUp.contains('CAUTION')) {
        canNavigate = false;
      }

      // 3. Get config and clean name
      final config = _getMarkerConfig(name, type);
      String displayName = name.replaceAll(RegExp(r'\[.*?\]'), '').trim();

      // 3. Dynamic Sizing
      double markerSize = 24.0; // Reduced from 28.0
      double iconSize   = 12.0; // Reduced from 14.0
      double borderWidth = 1.0; // Thinner border for havens
      double markerOpacity = isReferencePoint ? fadeOpacity : (havenFadeOpacity * 0.8); // Increased from 0.6
      
      if (isHarassment) {
        markerSize = 26.0;
        iconSize   = 13.0;
        borderWidth = 1.0; // Reduced from 1.5
        markerOpacity = fadeOpacity * 0.95;
      } else if (isLighting) {
        markerSize = 12.0;
        iconSize   = 10.0;
        borderWidth = 0.0;
        markerOpacity = fadeOpacity * 0.7;
      } else if (isReferencePoint) {
        // This covers Temple, Mall, Station, etc. 
        // Smaller than havens (28), bigger than lighting (16)
        markerSize = 18.0;
        iconSize = 8.0;
        borderWidth = 0.5; // Ultra thin border for secondary spots
        markerOpacity = fadeOpacity * 0.5; // Significantly reduced opacity
      }

      if (isZone) {
        // Physically accurate 1km radius scaling
        // Ground resolution at current zoom (meters per pixel)
        final groundRes = 156543.03 * math.cos(lat * math.pi / 180) / math.pow(2, _currentZoom);
        final pixelRadius = 1000 / groundRes; // 1000m = 1km
        
        markerSize = pixelRadius * 2; // Diameter
        markerSize = markerSize.clamp(40.0, 600.0); // Clamp to avoid screen-filling or invisible markers
        iconSize = 14.0; // Reduced from 18.0
        markerOpacity = zoneFadeOpacity * 0.7; // Reduced from 0.95
      }

      final markerWidget = GestureDetector(
        onTap: () => _showMarkerPopup(
          displayName, config.subtitle, config.icon, config.color, lat, lng,
          distance: h['distance_m'],
          showNavigate: canNavigate
        ),
        child: Container(
          decoration: BoxDecoration(
            color: (isLighting || isHarassment) ? config.color.withOpacity(isHarassment ? 0.9 : 0.6) : config.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity((isLighting || isHarassment) ? 0.6 : 1.0), width: borderWidth),
            boxShadow: [BoxShadow(color: config.color.withOpacity(0.3), blurRadius: isLighting ? 2 : 6)]
          ),
          child: Icon(config.icon, color: Colors.white, size: iconSize),
        )
      );

      markers.add(Marker(
        point: LatLng(lat, lng), 
        // Use full aura size to prevent culling, but keep hit-test area small
        width: markerSize, 
        height: markerSize,
        child: Opacity(
          opacity: markerOpacity, 
          child: isZone 
            ? Stack(
                alignment: Alignment.center, 
                children: [
                  // 1. Heatmap Aura (Full marker size)
                  IgnorePointer(
                    child: Container(
                      width: markerSize, height: markerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          config.color.withOpacity(0.55),
                          config.color.withOpacity(0.25),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  // 2. Clickable Icon Core
                  GestureDetector(
                    onTap: () => _showMarkerPopup(
                      displayName, config.subtitle, config.icon, config.color, lat, lng,
                      distance: h['distance_m'], showNavigate: canNavigate
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: config.color.withOpacity(0.95),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.0),
                      ),
                      child: Icon(config.icon, color: Colors.white, size: iconSize),
                    ),
                  ),
                ],
              )
            : markerWidget, // Standard markers use their full size
        ),
      ));
    }

    // Reports (unsafe)
    for (final r in _reports) {
      final lat = r['lat'] as double?; final lng = r['lng'] as double?;
      if (lat == null || lng == null) continue;
      markers.add(Marker(point: LatLng(lat, lng), width: 32, height: 32,
        child: GestureDetector(
          onTap: () => _showMarkerPopup('User Report', r['report_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Warning', Icons.warning_amber_rounded, Colors.orange, lat, lng, showNavigate: false),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 6)]
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
          )
        )
      ));
    }

    // 3. System Markers (Location & Endpoints) - Unclustered
    final systemMarkers = <Marker>[];
    systemMarkers.add(Marker(point: _myPos, width: 42, height: 42, child: _MyDot(heading: _heading))); // Increased from 30
    // Origin dot removed to avoid overlapping with navigation arrow
    if (_to != null) {
      systemMarkers.add(Marker(
        point: LatLng(_to!.lat, _to!.lng), width: 36, height: 36, 
        child: Transform.translate(
          offset: const Offset(0, -20), // Visually shifts the pin upwards!
          child: const Icon(Icons.location_pin, color: Color(0xFFFF3B30), size: 36)
        )
      ));
    }

    return PopScope(
      // Back button: close search / route panel instead of exiting
      canPop: !_searchOpen && _routes.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_searchOpen) {
            _onSearchCloseTap();
          } else if (_routes.isNotEmpty) {
            if (!_routePanelMinimized) {
              setState(() => _routePanelMinimized = true);
            } else if (!_journeyActive) {
              setState(() {
                _routes = [];
                _selected = null;
                _from = null;
                _to = null;
                _fromCtrl.clear();
                _toCtrl.clear();
                _routePanelMinimized = false;
              });
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [

          // ── MAP ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _myPos,
              initialZoom:   15,
              onTap: (_, _) {
                if (_searchOpen) {
                  _closeSearch();
                } else if (_routes.isNotEmpty && !_routePanelMinimized) {
                  setState(() => _routePanelMinimized = true);
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd || event is MapEventMove || event is MapEventRotate || event is MapEventRotateEnd) {
                  if (mounted && (_currentZoom != _mapCtrl.camera.zoom || _currentRotation != _mapCtrl.camera.rotation)) {
                    setState(() {
                      _currentZoom = _mapCtrl.camera.zoom;
                      _currentRotation = _mapCtrl.camera.rotation;
                    });
                  }
                }
                if (event is MapEventMoveEnd) {
                  _poiDebounce?.cancel();
                  _poiDebounce = Timer(const Duration(milliseconds: 600), _fetchPOIs);
                }
              },
            ),
            children: [
              isDark
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255,
                         0, -1,  0, 0, 255,
                         0,  0, -1, 0, 255,
                         0,  0,  0, 1,   0,
                      ]),
                      child: TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.safarsathi.app',
                        retinaMode: true,
                      ),
                    )
                  : TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.safarsathi.app',
                      retinaMode: true,
                    ),
              PolylineLayer(polylines: polylines),
              
              // All Markers
              MarkerLayer(markers: markers),

              // System Markers (User, Route Endpoints)
              MarkerLayer(markers: systemMarkers),
            ],
          ),

          // ── NAVIGATION HUD ──
          if (_journeyActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16, right: 16,
              child: _GlassBox(
                surface: const Color(0xFF007AFF),
                border: border, radius: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(_navIcon, color: Colors.white, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_navInstruction, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('in ${_navDistance.round()} meters', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.5),
            ),

          // ── TOP OVERLAYS (Grouped to prevent glassmorphism stacking artifacts) ──
          if (!_journeyActive)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── TOP BAR ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _GlassBox(
                      surface: surface, border: border,
                      radius: 20,
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 150), // Fast as fuck
                        sizeCurve: Curves.easeInOutCubic,
                        crossFadeState: _searchOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: _SearchCollapsed(onTap: _openSearch),
                        secondChild: _SearchExpanded(
                          fromCtrl:  _fromCtrl,  toCtrl:    _toCtrl,
                          fromFocus: _fromFocus, toFocus:   _toFocus,
                          onFromChange: (q) => _onSearchType(q, true),
                          onToChange:   (q) => _onSearchType(q, false),
                          onFromTap:    () => setState(() => _pickingFrom = true),
                          onToTap:      () => setState(() => _pickingFrom = false),
                          onMyLocation: _useMyLocation,
                          onClose: _onSearchCloseTap,
                          onSubmit: _findRoutes,
                          onFromClear: () => setState(() => _from = null),
                          onToClear: () => setState(() { _to = null; _routes = []; _selected = null; _routePanelMinimized = false; }),
                        ),
                      ),
                    ),
                  ),

                  // ── SUGGESTIONS ──
                  if (_suggestions.isNotEmpty)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _GlassBox(
                          surface: surface, border: border, radius: 16,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount:  _suggestions.length,
                            separatorBuilder: (context, index) => Divider(height: 0, color: border),
                            itemBuilder: (context, i) {
                              final p = _suggestions[i];
                              return Material(color: Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.place_rounded,
                                      color: colors.textMuted, size: 18),
                                  title: Text(p.label.split(',').first,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: Text(p.label.split(',').skip(1).join(',').trim(),
                                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => _pickSuggestion(p),
                                ));
                            },
                          ),
                        ).animate().fadeIn(duration: 180.ms).slideY(begin: -0.1),
                      ),
                    ),

                  // ── LOADING ──
                  if (_routing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _GlassBox(surface: surface, border: border, radius: 14,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.safeColor)),
                            const SizedBox(width: 12),
                            const Text('Finding safest routes...', style: TextStyle(fontSize: 14)),
                          ]),
                        )),
                    ),

                  // ── ROUTE ERROR ──
                  if (_routeErr != null && !_routing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _GlassBox(surface: surface, border: border, radius: 14,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, color: colors.warningColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_routeErr!, style: TextStyle(fontSize: 13, color: colors.warningColor))),
                            GestureDetector(onTap: () => setState(() => _routeErr = null),
                              child: Icon(Icons.close_rounded, color: colors.textMuted, size: 18)),
                          ]),
                        )),
                    ).animate().fadeIn(),
                ],
              ),
            ),
          ),

          // ── COMPASS BUTTON ─────────────────────────────────────────────
          Positioned(right: 20, bottom: 256, // Sits exactly above My Location button
            child: IgnorePointer(
              ignoring: _currentRotation.abs() <= 1.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600), // Slower fade
                opacity: _currentRotation.abs() > 1.0 ? 1.0 : 0.0,
                child: _FloatBtn(
                  icon: Icons.navigation_rounded,
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  iconColor: const Color(0xFFFF3B30), // Red needle for North
                  rotation: -_currentRotation * (math.pi / 180), // Points perfectly North!
                  onTap: _animatedRotateToNorth, // Smooth, slow rotation
                ),
              ),
            ),
          ),

          // ── MY LOCATION BUTTON ─────────────────────────────────────────
          Positioned(right: 20, bottom: 200, // Moved up to clear new dock
            child: _FloatBtn(
              icon: Icons.my_location_rounded,
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              iconColor: const Color(0xFF007AFF),
              onTap: _centerOnMe,
            ),
          ),

          // ── ROUTE PANEL ────────────────────────────────────────────────
          if (_routes.isNotEmpty && _selected != null)
            Positioned(bottom: 0, left: 0, right: 0,
              child: (_routePanelMinimized || _journeyActive)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _GlassBox(
                        surface: surface, border: border, radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(_journeyActive ? Icons.navigation_rounded : Icons.route_rounded, 
                                color: _journeyActive ? const Color(0xFFFF3B30) : _selected!.color, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_journeyActive ? 'Journey Active' : 'Route Selected', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text('${_from?.label.split(',').first ?? ''} → ${_to?.label.split(',').first ?? ''}', 
                                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (_journeyActive)
                                FilledButton(
                                  onPressed: _endJourney,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3B30),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('End', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _journeyActive ? null : () => setState(() => _routePanelMinimized = false),
                                icon: const Icon(Icons.expand_less_rounded),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().slideY(begin: 1, duration: 380.ms, curve: Curves.easeOutCubic)
                : _RoutePanel(
                    routes:   _routes,
                    selected: _selected!,
                    from:     _from?.label ?? '',
                    to:       _to?.label ?? '',
                    journey:  _journeyActive,
                    canStart: _from == null || const Distance().as(LengthUnit.Meter, _myPos, LatLng(_from!.lat, _from!.lng)) <= 100,
                    onSelect: (r) { setState(() => _selected = r); _fitRoute(r.coords); },
                    onStart:  _startJourney,
                    onEnd:    _endJourney,
                    onMinimize: () => setState(() => _routePanelMinimized = true),
                    dist:     _dist,
                    time:     _time,
                    surface:  surface, border: border,
                  ).animate().slideY(begin: 1, duration: 380.ms, curve: Curves.easeOutCubic),
            ),

          // ── BOTTOM DOCK ────────────────────────────────────────────────
          if (_routes.isEmpty)
            Positioned(bottom: 0, left: 0, right: 0,
              child: _BottomDock(
                surface:     surface, border: border,
                sosProg:     _sosProg, sosHeld: _sosHeld,
                onSosStart:  _sosStart, onSosEnd: _sosEnd,
                onHavens:    _openHavens,
                onReport:    _openReport,
                onSafeRoute: _openSearch,
              ).animate().slideY(begin: 1, duration: 420.ms, curve: Curves.easeOutCubic),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROUTE DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _RouteOption {
  final String id, pref, label;
  final double safety, distM;
  final int    walkMin, driveMin;
  final List<LatLng> coords;
  final List<Map<String,dynamic>> segments;

  _RouteOption({required this.id, required this.pref, required this.label,
      required this.safety, required this.distM,
      required this.walkMin, required this.driveMin,
      required this.coords, required this.segments});

  Color get color {
    if (safety >= 0.65) return const Color(0xFF30D158);
    if (safety >= 0.45) return const Color(0xFFFFD60A);
    return const Color(0xFFFF453A);
  }

  String get prefLabel => switch (pref) {
    'safest'   => 'Safest',
    'shortest' => 'Shortest',
    _          => 'Balanced',
  };

  IconData get prefIcon => switch (pref) {
    'safest'   => Icons.shield_rounded,
    'shortest' => Icons.bolt_rounded,
    _          => Icons.balance_rounded,
  };

  String get safePeriod {
    if (safety >= 0.8) return 'Safe 24/7 (Lit/Crowded)';
    if (safety >= 0.6) return 'Safe during active hours';
    if (safety >= 0.4) return 'Daytime only';
    return 'High crime zone - Avoid';
  }

  String get cautionPeriod {
    if (safety >= 0.8) return 'None';
    if (safety >= 0.6) return 'After 10 PM (Low Crowd)';
    if (safety >= 0.4) return 'After Sunset (Poor Light)';
    return 'Always';
  }

  String nowStatus() {
    final h = DateTime.now().hour;
    if (safety >= 0.65) return h >= 22 || h < 5 ? 'Moderate right now' : 'Safe right now';
    if (safety >= 0.45) return h >= 20 || h < 6 ? 'Use caution right now' : 'Moderate right now';
    return h >= 18 || h < 9 ? 'Avoid — high risk right now' : 'Caution during day';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// Liquid glass box
class _GlassBox extends StatelessWidget {
  final Widget child;
  final Color  surface, border;
  final double radius;
  const _GlassBox({required this.child, required this.surface,
      required this.border, required this.radius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        // 1. The Blur Effect
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // 2. The "Liquid" Surface Gradient
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.15 : 0.9), // Top-left shine
                surface.withValues(alpha: isDark ? 0.4 : 0.85), // Center transparency mapped to theme
              ],
            ),
            // 3. The Subtle Border (Refraction)
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
              width: 1.5,
            ),
            // 4. Inner Shadow / Depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: -2,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Collapsed search bar
class _SearchCollapsed extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchCollapsed({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SafarSathiColors>()!;
    return GestureDetector(onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            (context.findAncestorStateOfType<_HomeScreenState>()?._from != null && 
             context.findAncestorStateOfType<_HomeScreenState>()?._to != null) 
              ? '${context.findAncestorStateOfType<_HomeScreenState>()!._from!.label.split(',').first} → ${context.findAncestorStateOfType<_HomeScreenState>()!._to!.label.split(',').first}'
              : 'Where to?',
            style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w400))),
          Container(width: 1, height: 18,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF007AFF).withAlpha(150), width: 1.5),
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFF007AFF), size: 16),
            ),
          ),
        ]),
      ));
  }
}

// Expanded search with origin + destination
class _SearchExpanded extends StatelessWidget {
  final TextEditingController fromCtrl, toCtrl;
  final FocusNode fromFocus, toFocus;
  final ValueChanged<String> onFromChange, onToChange;
  final VoidCallback onFromTap, onToTap, onMyLocation, onClose, onSubmit, onFromClear, onToClear;

  const _SearchExpanded({
    required this.fromCtrl, required this.toCtrl,
    required this.fromFocus, required this.toFocus,
    required this.onFromChange, required this.onToChange,
    required this.onFromTap, required this.onToTap,
    required this.onMyLocation, required this.onClose, required this.onSubmit,
    required this.onFromClear, required this.onToClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors  = Theme.of(context).extension<SafarSathiColors>()!;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final divider = Divider(height: 0, indent: 48, endIndent: 0,
        color: isDark ? Colors.white12 : Colors.black12);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // From
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(children: [
          const Icon(Icons.trip_origin_rounded, color: Color(0xFF007AFF), size: 18),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: fromCtrl, focusNode: fromFocus,
            onTap: onFromTap, onChanged: onFromChange,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Start location',
              hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 15, fontWeight: FontWeight.w400),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          )),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: fromCtrl,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox();
              return GestureDetector(
                onTap: () {
                  fromCtrl.clear();
                  onFromClear();
                  onFromChange('');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.cancel_rounded, color: colors.textMuted.withAlpha(150), size: 18),
                ),
              );
            },
          ),
          GestureDetector(onTap: onMyLocation,
            child: Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withAlpha(31),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF007AFF), size: 16))),
        ]),
      ),
      const SizedBox(height: 10),
      divider,
      const SizedBox(height: 10),
      // To
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          const Icon(Icons.location_pin, color: Color(0xFFFF3B30), size: 18),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: toCtrl, focusNode: toFocus,
            onTap: onToTap, onChanged: onToChange,
            onSubmitted: (_) => onSubmit(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Where to?',
              hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 15, fontWeight: FontWeight.w400),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          )),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: toCtrl,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox();
              return GestureDetector(
                onTap: () {
                  toCtrl.clear();
                  onToClear();
                  onToChange('');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.cancel_rounded, color: colors.textMuted.withAlpha(150), size: 18),
                ),
              );
            },
          ),
          GestureDetector(onTap: onClose,
            child: Icon(Icons.arrow_upward_rounded, color: colors.textMuted, size: 20)),
        ]),
      ),
    ]);
  }
}

// Route panel (slides up from bottom)
class _RoutePanel extends StatelessWidget {
  final List<_RouteOption> routes;
  final _RouteOption selected;
  final String from, to;
  final bool   journey, canStart;
  final ValueChanged<_RouteOption> onSelect;
  final VoidCallback onStart, onEnd, onMinimize;
  final String Function(_RouteOption) dist, time;
  final Color surface, border;

  const _RoutePanel({
    required this.routes, required this.selected,
    required this.from, required this.to,
    required this.journey, required this.canStart,
    required this.onSelect, required this.onStart, required this.onEnd, required this.onMinimize,
    required this.dist, required this.time,
    required this.surface, required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SafarSathiColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Container(
        color: isDark ? const Color(0xF01C1C1E) : const Color(0xF0FFFFFF),
        child: SafeArea(top: false, child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          GestureDetector(
            onTap: onMinimize,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: Center(child: Container(width: 36, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2)))),
            ),
          ),

          // From → To summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Route', style: TextStyle(fontSize: 12, color: colors.textMuted,
                      fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('${from.split(',').first} → ${to.split(',').first}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              // Safety badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected.color.withAlpha(31),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected.color.withAlpha(77)),
                ),
                child: Text(selected.label,
                  style: TextStyle(fontSize: 12, color: selected.color,
                      fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // Route options chips (horizontal scroll)
          SizedBox(height: 120, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: routes.length,
            itemBuilder: (_, i) {
              final r    = routes[i];
              final isSel = r == selected;
              return GestureDetector(
                onTap: () => onSelect(r),
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  width: 130,
                  decoration: BoxDecoration(
                    color:        isSel ? r.color.withAlpha(26) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border:       Border.all(
                      color: isSel ? r.color : (isDark ? Colors.white12 : Colors.black12),
                      width: isSel ? 1.5 : 0.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(r.prefIcon, size: 14, color: r.color),
                      const SizedBox(width: 5),
                      Text(r.prefLabel, style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: r.color)),
                    ]),
                    const SizedBox(height: 4),
                    Text(dist(r), style: TextStyle(fontSize: 12, color: colors.textMuted)),
                    Text(time(r), style: TextStyle(fontSize: 12, color: colors.textMuted)),
                    Text('${(r.safety*100).round()}% safe',
                        style: TextStyle(fontSize: 11, color: r.color, fontWeight: FontWeight.w500)),
                  ]),
                ),
              );
            },
          )),

          // Safety time info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Expanded(child: _TimeChip(Icons.wb_sunny_rounded, 'Safe: ${selected.safePeriod}', const Color(0xFF30D158))),
              const SizedBox(width: 8),
              Expanded(child: _TimeChip(Icons.nightlight_rounded, 'Caution: ${selected.cautionPeriod}', const Color(0xFFFF9500))),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: selected.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(selected.nowStatus(),
                style: TextStyle(fontSize: 12, color: colors.textMuted)),
            ]),
          ),

          const SizedBox(height: 14),

          // Start / End button
          if (journey || canStart)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(width: double.infinity, height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: journey ? const Color(0xFFFF3B30) : selected.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: journey ? onEnd : onStart,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(journey ? Icons.stop_rounded : Icons.navigation_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(journey ? 'End Journey' : 'Start Journey',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  ]),
                )),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(77)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Move closer to start location to begin navigation', 
                    style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
        ])
        )),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _TimeChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 4),
      Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// Bottom dock
class _BottomDock extends StatelessWidget {
  final Color surface, border;
  final double sosProg;
  final bool   sosHeld;
  final VoidCallback onSosStart, onSosEnd, onHavens, onReport, onSafeRoute;

  const _BottomDock({
    required this.surface, required this.border,
    required this.sosProg, required this.sosHeld,
    required this.onSosStart, required this.onSosEnd,
    required this.onHavens, required this.onReport, required this.onSafeRoute,
  });

  @override
  Widget build(BuildContext context) => SafeArea(top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), // Moved up slightly
      child: _GlassBox(
        surface: surface,
        border: border,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _DockItem(icon: Icons.local_police_rounded, label: 'Havens',
                    color: const Color(0xFF007AFF), onTap: onHavens),
                _SosItem(prog: sosProg, held: sosHeld,
                    onStart: onSosStart, onEnd: onSosEnd),
                _DockItem(icon: Icons.campaign_rounded, label: 'Report',
                    color: const Color(0xFFFF9500), onTap: onReport),
                // Safe Route removed to make dock cleaner and wider!
              ]),
        ),
      ),
    ),
  );
}

class _DockItem extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _DockItem({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 60, // Wider
        decoration: BoxDecoration(color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, color: color, size: 28)), // Larger icon
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)), // Larger text
    ]));
}

class _SosItem extends StatelessWidget {
  final double prog; final bool held;
  final VoidCallback onStart, onEnd;
  const _SosItem({required this.prog, required this.held, required this.onStart, required this.onEnd});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart:  (_) => onStart(),
    onLongPressEnd:    (_) => onEnd(),
    onLongPressCancel: onEnd,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(width: 72, height: 72, child: CircularProgressIndicator(
          value: prog, strokeWidth: 4,
          color: const Color(0xFFFF3B30),
          backgroundColor: const Color(0xFFFF3B30).withAlpha(46))),
        AnimatedContainer(duration: 150.ms,
          width: held ? 68 : 64, height: held ? 68 : 64, // Larger SOS button
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(24),
            boxShadow: held ? [BoxShadow(color: const Color(0xFFFF3B30).withAlpha(140),
                blurRadius: 20, spreadRadius: 4)] : []),
          child: const Icon(Icons.sos_rounded, color: Colors.white, size: 32)),
      ]),
      const SizedBox(height: 6),
      const Text('Hold 3s', style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w700, color: Color(0xFFFF3B30))),
    ]));
}

// My location animated dot
class _MyDot extends StatefulWidget {
  final double? heading;
  const _MyDot({this.heading});
  @override State<_MyDot> createState() => _MyDotState();
}
class _MyDotState extends State<_MyDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: 2.seconds)..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (context, child) => // Standard naming often clears this lint
    Stack(alignment: Alignment.center, children: [
      Container(width: 30 + _a.value * 8, height: 30 + _a.value * 8, // Increased ripple
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF007AFF).withValues(
  alpha: 0.25 - _a.value * 0.2,
))),
      Transform.rotate(
        angle: (widget.heading ?? 0.0) * (math.pi / 180),
        child: Container(
          width: 36, height: 36, // Increased from 26
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withAlpha(102), blurRadius: 8)]
          ),
          child: const Center(
            child: Icon(Icons.navigation_rounded, color: Color(0xFF007AFF), size: 24) // Increased from 18
          ),
        ),
      ),
    ]));
}

// Float button with Liquid Glass
class _FloatBtn extends StatelessWidget {
  final IconData icon; final Color color, iconColor; final VoidCallback onTap;
  final double rotation;
  const _FloatBtn({required this.icon, required this.color, required this.iconColor, required this.onTap, this.rotation = 0.0});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: _GlassBox(
      radius: 22, // Makes it a perfect circle for a 44px height
      surface: color,
      border: Colors.white,
      child: SizedBox(
        width: 44, height: 44,
        child: Transform.rotate(
          angle: rotation,
          child: Icon(icon, color: iconColor, size: 22)
        ),
      ),
    ),
  );
}

// Haven pin (Keeping it solid for high visibility on map)
class _HavenDot extends StatelessWidget {
  final String type;
  const _HavenDot({required this.type});
  @override
  Widget build(BuildContext context) {
    final c = switch (type) {
      'police_station' => const Color(0xFF007AFF),
      'hospital'       => const Color(0xFFFF3B30),
      'pharmacy'       => const Color(0xFF30D158),
      _                => const Color(0xFF8E8E93),
    };
    return _GlassBox(
      radius: 16,
      surface: c,
      border: Colors.white.withValues(alpha: 0.5),
      child: Icon(_iconFor(type), color: Colors.white, size: 14)
    );
  }
  IconData _iconFor(String t) => switch (t) {
    'police_station' => Icons.local_police_rounded,
    'hospital'       => Icons.local_hospital_rounded,
    'pharmacy'       => Icons.medical_services_rounded,
    _                => Icons.shield_rounded,
  };
}

class _ReportSheet extends StatelessWidget {
  final LatLng pos;
  const _ReportSheet({required this.pos});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final types = [
      ('poor_lighting', 'Poor Lighting', Icons.light_mode_outlined, const Color(0xFFFF9500)),
      ('harassment_incident', 'Harassment', Icons.warning_amber_rounded, const Color(0xFFFF3B30)),
      ('unsafe_area', 'Unsafe Area', Icons.dangerous_rounded, const Color(0xFFFF3B30)),
      ('safe_haven', 'Safe Haven', Icons.shield_rounded, const Color(0xFF30D158)),
      ('good_lighting', 'Good Lighting', Icons.lightbulb_rounded, const Color(0xFFFFD60A)),
      ('police_presence', 'Police Here', Icons.local_police_rounded, const Color(0xFF007AFF)),
    ];

    return _GlassBox(
      radius: 26,
      surface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      border: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Report at this location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: types.map((t) => GestureDetector(
                  onTap: () async {
                    final type = t.$1;
                    final label = t.$2;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    
                    try {
                      await api.submitReport(
                        reportType: type,
                        lat: pos.latitude,
                        lng: pos.longitude,
                        description: 'User report: $label',
                      );
                      
                      messenger.showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text('$label reported successfully!', 
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                        backgroundColor: const Color(0xFF30D158),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        duration: const Duration(seconds: 3),
                      ));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(
                        content: Text('Failed to submit report: $e'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: t.$4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.$4.withValues(alpha: 0.2))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.$3, color: t.$4, size: 24),
                        const SizedBox(height: 6),
                        Text(t.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.$4)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HavensSheet extends StatelessWidget {
  final List<dynamic> havens;
  final double radius;
  final void Function(double) onRadiusChange;
  final Function(Map<String, dynamic> haven) onSelect;
  
  const _HavensSheet({required this.havens, required this.radius, required this.onRadiusChange, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).extension<SafarSathiColors>()!;

    return _GlassBox(
      radius: 26,
      surface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      border: Colors.white,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.fromLTRB(0, 10, 0, 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Text('Safe Havens Nearby',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Within 2km', style: TextStyle(fontSize: 12, color: colors.safeColor, fontWeight: FontWeight.w600)),
            ])),
          Flexible(child: havens.where((h) {
                    if (h['name']?.toString().startsWith('[') ?? false) return false;
                    
                    final dist = h['distance_m'] ?? 0;
                    return dist <= 2000; // Only show in list if within 2km
                  }).isEmpty
              ? Padding(padding: const EdgeInsets.only(bottom: 24), child: Text('No havens within 2km', style: TextStyle(color: colors.textMuted)))
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: havens.where((h) {
                    if (h['name']?.toString().startsWith('[') ?? false) return false;
                    
                    final dist = h['distance_m'] ?? 0;
                    return dist <= 2000;
                  }).length,
                  itemBuilder: (_, i) {
                    final filtered = havens.where((h) {
                    if (h['name']?.toString().startsWith('[') ?? false) return false;
                      
                      final dist = h['distance_m'] ?? 0;
                      return dist <= 2000;
                    }).toList();
                    
                    final h = filtered[i];
                    final c = _colorFor(h['place_type'] ?? '');
                    return GestureDetector(
                      onTap: () => onSelect(h),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.withValues(alpha: 0.2))),
                        child: Row(children: [
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_iconFor(h['place_type'] ?? ''), color: c, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h['name']?.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim() ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            Text('${h['distance_m'] ?? 0}m', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        ]),
                      ),
                    );
                  })),
        ]),
      ),
    );
  }

  Color _colorFor(String t) => switch (t) { 'police_station' => const Color(0xFF007AFF), 'hospital' => const Color(0xFFFF3B30), 'pharmacy' => const Color(0xFF30D158), _ => const Color(0xFF8E8E93) };
  IconData _iconFor(String t) => switch (t) { 'police_station' => Icons.local_police_rounded, 'hospital' => Icons.local_hospital_rounded, 'pharmacy' => Icons.medical_services_rounded, _ => Icons.shield_rounded };
}

class _RadiusBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RadiusBtn(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? (isDark ? Colors.white24 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active && !isDark ? [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
          ),
        ),
      ),
    );
  }
}