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
  String telemetryStatus = 'Telemetry not sent yet';
  bool isInRedZone = false;

  // Failsafe: brak odpowiedzi serwera dłużej niż _offlineLockTimeout -> pojazd blokuje się sam
  static const Duration _offlineLockTimeout = Duration(seconds: 30);
  static const int _maxBufferedPoints = 60; // ok. 5 min przy wysyłce co 5 s
  bool offlineLocked = false;
  DateTime _lastServerContact = DateTime.now();
  final List<_TelemetryPoint> _pendingPoints = [];

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
  Timer? _lockAckTimer; // ponawianie potwierdzenia blokady do skutku

  bool get isRented => selectedStatus?.id == 2;
  // Tryb serwisowy: technik rozpoczął naprawę (status InService) i potrzebuje odblokowanego pojazdu
  bool get isInService => selectedStatus?.id == 4;
  // Pojazd odblokowany: wypożyczony albo w serwisie. Każdy inny status = blokada.
  bool get isUnlocked => isRented || isInService;

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
      if (updatedVehicles.isEmpty) {
        _checkOfflineLock();
        return;
      }
      _onServerContact();

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
    if (isUnlocked) {
      _startTelemetry();
    } else {
      speed = 0.0;
      offlineLocked = false;
      _pendingPoints.clear();
      _stopTelemetry();
      if (selectedVehicle != null) _startLockAck();
    }
  }

  // Potwierdzenie blokady: pojazd wysyła podpisaną wiadomość z locked: true
  // i ponawia ją co 5 s, dopóki serwer jej nie przyjmie (np. po odzyskaniu łączności).
  void _startLockAck() {
    _lockAckTimer?.cancel();
    _sendLockAck();
    _lockAckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendLockAck());
  }

  Future<void> _sendLockAck() async {
    if (qrCode.isEmpty || x == 0 || y == 0) return;
    final result = await ApiService.sendTelemetry(qrCode, battery, x, y, 0, locked: true);
    if (result == TelemetryResult.ok) {
      _lockAckTimer?.cancel();
      telemetryStatus = 'Lock confirmed to server';
    } else if (result == TelemetryResult.noDeviceKey || result == TelemetryResult.unauthorized) {
      _lockAckTimer?.cancel(); // urządzenie nie jest zarejestrowane, ponawianie nic nie da
      telemetryStatus = 'Lock not confirmed: device not registered';
    } else {
      telemetryStatus = 'Lock not confirmed yet (retrying)';
    }
    notifyListeners();
  }

  // Serwer odpowiedział: jeśli pojazd był zablokowany z powodu braku łączności,
  // a pojazd nadal ma być odblokowany (status Rented lub InService), odblokowujemy go.
  void _onServerContact() {
    _lastServerContact = DateTime.now();
    if (offlineLocked) {
      offlineLocked = false;
      if (kDebugMode) print("Connection restored: vehicle unlocked.");
      notifyListeners();
    }
  }

  // Brak odpowiedzi serwera przez _offlineLockTimeout, gdy pojazd jest odblokowany (wypożyczenie lub serwis) -> blokada (prędkość 0).
  void _checkOfflineLock() {
    if (!isUnlocked || offlineLocked) return;
    if (DateTime.now().difference(_lastServerContact) > _offlineLockTimeout) {
      offlineLocked = true;
      speed = 0.0;
      telemetryStatus = 'NO CONNECTION - LOCKED';
      if (kDebugMode) print("No server response for ${_offlineLockTimeout.inSeconds} s: vehicle locked.");
      notifyListeners();
    }
  }

  void _startTelemetry() {
    _lastServerContact = DateTime.now();
    _lockAckTimer?.cancel();
    _telemetryTimer?.cancel();
    sendToAPI(); // Відправляємо миттєво перший раз
    // Запускаємо строгий таймер кожні 5 секунд
    _telemetryTimer = Timer.periodic(const Duration(seconds: 5), (_) => sendToAPI());
  }

  void _stopTelemetry() {
    _telemetryTimer?.cancel();
    _lockAckTimer?.cancel();
  }

  void updateSpeed(double val) {
    if (!isUnlocked) return;
    
    if (offlineLocked || isInRedZone || maxAllowedSpeed == 0) {
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
      final point = _TelemetryPoint(battery, x, y, speed);
      final result = await ApiService.sendTelemetry(qrCode, point.battery, point.x, point.y, point.speed);

      if (result == TelemetryResult.error) {
        // Brak łączności: punkt trafia do bufora i zostanie wysłany po odzyskaniu połączenia
        _pendingPoints.add(point);
        if (_pendingPoints.length > _maxBufferedPoints) _pendingPoints.removeAt(0);
        _checkOfflineLock();
        if (offlineLocked) {
          telemetryStatus = 'NO CONNECTION - LOCKED (${_pendingPoints.length} points buffered)';
          notifyListeners();
          return;
        }
      } else if (result == TelemetryResult.ok) {
        _onServerContact();
        await _flushPendingPoints();
      }

      telemetryStatus = switch (result) {
        TelemetryResult.ok => 'Telemetry accepted (server verified)',
        TelemetryResult.noDeviceKey => 'No DEVICE_KEY in .env',
        TelemetryResult.unauthorized => 'Rejected: device not registered or wrong key',
        TelemetryResult.serverNotVerified => 'Server signature invalid: response ignored',
        TelemetryResult.error => 'Telemetry error (no connection?)',
      };
      notifyListeners();
    }
  }

  // Wysyła zbuforowane punkty w kolejności; przerywa przy pierwszym błędzie.
  Future<void> _flushPendingPoints() async {
    while (_pendingPoints.isNotEmpty) {
      final p = _pendingPoints.first;
      final r = await ApiService.sendTelemetry(qrCode, p.battery, p.x, p.y, p.speed);
      if (r != TelemetryResult.ok) break;
      _pendingPoints.removeAt(0);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _telemetryTimer?.cancel();
    _dbUpdateTimer?.cancel();
    _lockAckTimer?.cancel();
    super.dispose();
  }
}

class _TelemetryPoint {
  final double battery;
  final double x;
  final double y;
  final double speed;

  _TelemetryPoint(this.battery, this.x, this.y, this.speed);
}
