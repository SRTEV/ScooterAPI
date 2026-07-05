import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ScooterViewModel extends ChangeNotifier {
  int vehicleId = 1;
  double speed = 0;
  double battery = 100;
  double latitude = 0.0;
  double longitude = 0.0;
  String locationStatus = 'Waiting for GPS...';
  bool isSimulating = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _telemetryTimer;

  ScooterViewModel() {
    _startTracking();
  }

  void _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      locationStatus = 'GPS is disabled';
      notifyListeners();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        locationStatus = 'GPS permissions denied';
        notifyListeners();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      locationStatus = 'GPS permissions permanently denied';
      notifyListeners();
      return;
    }

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    } else {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
    .listen((pos) {
      latitude = pos.latitude;
      longitude = pos.longitude;
      locationStatus = 'Real-time tracking active';
      notifyListeners();
    }, onError: (e) {
      locationStatus = 'Error: $e';
      notifyListeners();
    });
  }

  void updateSpeed(double val) { speed = val; notifyListeners(); }
  void updateBattery(double val) { battery = val; notifyListeners(); }

  void toggleSimulation() {
    isSimulating = !isSimulating;
    if (isSimulating) {
      _telemetryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendTelemetry());
    } else {
      _telemetryTimer?.cancel();
    }
    notifyListeners();
  }

  Future<void> _sendTelemetry() async {

    final url = Uri.parse('http://192.168.x.x:3000/api/telemetry'); 
    
    final payload = {
      'vehicleId': vehicleId,
      'batteryLevel': battery.toInt(),
      'positionX': latitude,
      'positionY': longitude,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      debugPrint("Telemetry sent: $payload, Status: ${response.statusCode}");
    } catch (e) { 
      debugPrint("Error sending telemetry: $e"); 
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }
}