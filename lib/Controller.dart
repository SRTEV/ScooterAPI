import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'db.dart';
import 'models.dart';

class ScooterViewModel extends ChangeNotifier {
  double speed = 0;
  double maxAllowedSpeed = 20.0;
  double battery = 100;
  double x = 0.0;
  double y = 0.0;
  String qrCode = '';
  String locationStatus = 'Waiting for GPS...';
  bool isInRedZone = false;

  List<VehicleType> vehicleTypes = [];
  List<Vehicle> allVehicles = [];
  List<Vehicle> filteredVehicles = [];
  List<Zone> zones = [];
  
  List<VehicleStatus> statuses = [
    VehicleStatus(id: 1, name: 'Available'),
    VehicleStatus(id: 2, name: 'Rented'),
    VehicleStatus(id: 3, name: 'NeedCheck'),
    VehicleStatus(id: 4, name: 'InService'),
  ];

  VehicleType? selectedType;
  Vehicle? selectedVehicle;
  VehicleStatus? selectedStatus;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _telemetryTimer;

  bool get isRented => selectedStatus?.id == 2;

  ScooterViewModel() {
    _startTracking();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    vehicleTypes = await ApiService.getVehicleTypes();
    allVehicles = await ApiService.getVehicles();
    zones = await ApiService.getZones();
    notifyListeners();
  }

  void selectVehicleType(VehicleType? type) {
    selectedType = type;
    selectedVehicle = null;
    selectedStatus = null;
    speed = 0;
    _stopTelemetry();
    
    if (type != null) {
      filteredVehicles = allVehicles.where((v) => v.vehicleTypeId == type.id).toList();
    } else {
      filteredVehicles = [];
    }
    notifyListeners();
  }

  void selectVehicle(Vehicle? vehicle) {
    selectedVehicle = vehicle;
    if (vehicle != null) {
      qrCode = vehicle.qrCode;
      battery = vehicle.batteryLevel;
      selectedStatus = statuses.firstWhere(
        (s) => s.id == vehicle.vehicleStatusId,
        orElse: () => statuses.first,
      );
      _handleStatusChange();
    } else {
      selectedStatus = null;
      _stopTelemetry();
    }
    checkGeoZone();
    notifyListeners();
  }

  void updateStatus(VehicleStatus? status) {
    if (status == null || selectedVehicle == null) return;
    selectedStatus = status;
    selectedVehicle!.vehicleStatusId = status.id;
    _handleStatusChange();
    notifyListeners();
  }

  void _handleStatusChange() {
    if (isRented) {
      _startTelemetry();
    } else {
      speed = 0.0;
      _stopTelemetry();
    }
  }

  void _startTelemetry() {
    _telemetryTimer?.cancel();
    sendToAPI();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 15), (_) => sendToAPI());
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
  }

  void updateSpeed(double val) {
    if (!isRented) return;
    
    if (val > maxAllowedSpeed) {
      speed = maxAllowedSpeed;
    } else {
      speed = val;
    }
    notifyListeners();
  }

  void updateBattery(double val) {
    battery = val;
    notifyListeners();
  }

  void _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      locationStatus = 'GPS is disabled';
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
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

    LocationSettings locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(accuracy: LocationAccuracy.best, distanceFilter: 0, intervalDuration: const Duration(seconds: 1))
        : AppleSettings(accuracy: LocationAccuracy.best, distanceFilter: 0);

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      x = pos.latitude;
      y = pos.longitude;
      locationStatus = 'Real-time tracking active';
      checkGeoZone();
      notifyListeners();
    }, onError: (e) {
      locationStatus = 'Error: $e';
      notifyListeners();
    });
  }

  void checkGeoZone() {
    if (selectedVehicle == null || x == 0.0 || y == 0.0) return;

    bool restricted = false;

    for (var zone in zones) {
      if (zone.vehicleTypeId != selectedVehicle!.vehicleTypeId) {
        if (_isPointInPolygon(x, y, zone.points)) {
          restricted = true;
          break;
        }
      }
    }

    isInRedZone = restricted;

    if (isInRedZone) {
      maxAllowedSpeed = 0.0;
      speed = 0.0;
    } else {
      maxAllowedSpeed = 20.0;
    }
  }

  bool _isPointInPolygon(double px, double py, List<List<double>> polygon) {
    if (polygon.isEmpty) return false;
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i][0], yi = polygon[i][1];
      double xj = polygon[j][0], yj = polygon[j][1];

      bool intersect = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersect) isInside = !isInside;
      j = i;
    }
    return isInside;
  }

  Future<void> sendToAPI() async {
    if (x != 0 && y != 0 && qrCode.isNotEmpty) {
      await ApiService.sendTelemetry(qrCode, battery, x, y, speed);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }
}