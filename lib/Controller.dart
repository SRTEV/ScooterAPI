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
  Timer? _dbUpdateTimer; 

  bool get isRented => selectedStatus?.id == 2;

  ScooterViewModel() {
    _startTracking();
    loadInitialData();
    _startDbUpdates(); 
  }

  Future<void> loadInitialData() async {
    vehicleTypes = await ApiService.getVehicleTypes();
    allVehicles = await ApiService.getVehicles();
    zones = await ApiService.getZones();
    notifyListeners();
  }

  void _startDbUpdates() {
    _dbUpdateTimer?.cancel();
    _dbUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshVehiclesFromDb();
    });
  }

  Future<void> _refreshVehiclesFromDb() async {
    try {
      final updatedVehicles = await ApiService.getVehicles();
      if (updatedVehicles.isEmpty) return;

      allVehicles = updatedVehicles;

      if (selectedType != null) {
        filteredVehicles = allVehicles.where((v) => v.vehicleTypeId == selectedType!.id).toList();
      } else {
        filteredVehicles = [];
      }

      if (selectedVehicle != null) {
        final index = filteredVehicles.indexWhere((v) => v.id == selectedVehicle!.id);
        if (index != -1) {
          final oldStatusId = selectedStatus?.id;
          
          selectedVehicle = filteredVehicles[index];
          selectedStatus = statuses.firstWhere(
            (s) => s.id == selectedVehicle!.vehicleStatusId,
            orElse: () => statuses.first,
          );
          
          _checkZoneFromDbFlag();

          if (oldStatusId != selectedStatus!.id) {
            _handleStatusChange();
          }
        } else {
          selectedVehicle = null;
          selectedStatus = null;
          _stopTelemetry();
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Background vehicle update error: $e");
      }
    }
  }

  void _checkZoneFromDbFlag() {
    if (selectedVehicle == null) return;

    bool restricted = (selectedVehicle!.inZone == 1);

    if (isInRedZone != restricted) {
      isInRedZone = restricted;
      if (isInRedZone) {
        maxAllowedSpeed = 0.0;
        speed = 0.0;
      } else {
        maxAllowedSpeed = 20.0;
      }
      notifyListeners();
    }
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
      
      _checkZoneFromDbFlag(); 
      _handleStatusChange();
    } else {
      selectedStatus = null;
      _stopTelemetry();
    }
    notifyListeners();
  }

  void updateStatus(VehicleStatus? status) {
    if (status == null || selectedVehicle == null) return;
    
    if (selectedStatus?.id == status.id) return;

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
    sendToAPI(); // Відправляємо миттєво перший раз
    // Запускаємо строгий таймер кожні 5 секунд
    _telemetryTimer = Timer.periodic(const Duration(seconds: 5), (_) => sendToAPI());
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
  }

  void updateSpeed(double val) {
    if (!isRented) return;
    
    if (isInRedZone || maxAllowedSpeed == 0) {
      speed = 0;
    } else if (val > maxAllowedSpeed) {
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
      notifyListeners();
    }, onError: (e) {
      locationStatus = 'Error: $e';
      notifyListeners();
    });
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
    _dbUpdateTimer?.cancel();
    super.dispose();
  }
}