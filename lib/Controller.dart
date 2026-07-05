import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'db.dart';
class ScooterViewModel extends ChangeNotifier {
  double speed = 0;
  double battery = 100;
  double x = 0.0;
  double y = 0.0;
  String qrCode = '';
  String locationStatus = 'Waiting for GPS...';
  bool isSimulating = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _telemetryTimer;

  ScooterViewModel() {
    _startTracking();
    _initDatabase();
  }

  void _initDatabase() async {
    await DatabaseHelper.connectToDatabase();
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
      x = pos.latitude;
      y = pos.longitude;
      locationStatus = 'Real-time tracking active';
      notifyListeners();
    }, onError: (e) {
      locationStatus = 'Error: $e';
      notifyListeners();
    });
  }

  void updateSpeed(double val) { speed = val; notifyListeners(); }
  void updateBattery(double val) { battery = val; notifyListeners(); }
  void updateQrCode(String val) { qrCode = val; notifyListeners(); }

  void toggleSimulation() {
    isSimulating = !isSimulating;
    if (isSimulating) {
      _telemetryTimer = Timer.periodic(const Duration(seconds: 5), (_) => sendToDB());
    } else {
      _telemetryTimer?.cancel();
    }
    notifyListeners();
  }


  Future sendToDB() async {
    if (x != 0 && y != 0) {
      await DatabaseHelper.insertTelemetry(qrCode, battery, x, y);
    }
  }


  @override
  void dispose() {
    _positionSubscription?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }

}