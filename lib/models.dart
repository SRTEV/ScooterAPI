class VehicleStatus {
  final int id;
  final String name;

  VehicleStatus({required this.id, required this.name});

  factory VehicleStatus.fromJson(Map<String, dynamic> json) {
    return VehicleStatus(
      id: json['id'] ?? json['ID'],
      name: json['name'] ?? json['Name'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleStatus && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class VehicleType {
  final int id;
  final String name;

  VehicleType({required this.id, required this.name});

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] ?? json['ID'],
      name: json['name'] ?? json['Name'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleType && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Vehicle {
  final int id;
  final String qrCode;
  final String model;
  final int vehicleTypeId;
  int vehicleStatusId;
  final double batteryLevel;
  final double positionX;
  final double positionY;
  final int inZone; 

  Vehicle({
    required this.id,
    required this.qrCode,
    required this.model,
    required this.vehicleTypeId,
    required this.vehicleStatusId,
    required this.batteryLevel,
    required this.positionX,
    required this.positionY,
    required this.inZone,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Safely parse inZone whether it comes as bool (true/false) or int (1/0)
    dynamic rawInZone = json['in_Zone'] ?? json['In_Zone'] ?? json['inZone'] ?? 0;
    int finalInZone = 0;
    
    if (rawInZone is bool) {
      finalInZone = rawInZone ? 1 : 0;
    } else if (rawInZone is int) {
      finalInZone = rawInZone;
    }

    return Vehicle(
      id: json['id'] ?? json['ID'],
      qrCode: json['qrCode'] ?? json['QR_code'] ?? '',
      model: json['model'] ?? json['Model'] ?? '',
      vehicleTypeId: json['vehicle_TypeID'] ?? json['Vehicle_TypeID'] ?? json['vehicleTypeId'] ?? 0,
      vehicleStatusId: json['vehicle_StatusID'] ?? json['Vehicle_StatusID'] ?? json['vehicleStatusId'] ?? 1,
      batteryLevel: (json['battery_level'] ?? json['Battery_level'] ?? 0).toDouble(),
      positionX: (json['position_X'] ?? json['Position_X'] ?? 0.0).toDouble(),
      positionY: (json['position_Y'] ?? json['Position_Y'] ?? 0.0).toDouble(),
      inZone: finalInZone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Zone {
  final int id;
  final String name;
  final int vehicleTypeId;
  final List<List<double>> points;

  Zone({
    required this.id,
    required this.name,
    required this.vehicleTypeId,
    required this.points,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    String rawCoords = json['coordinates'] ?? json['Coordinates'] ?? '';
    List<List<double>> parsedPoints = [];
    if (rawCoords.isNotEmpty) {
      for (var pair in rawCoords.split(';')) {
        var parts = pair.trim().split(',');
        if (parts.length == 2) {
          double? lat = double.tryParse(parts[0].trim());
          double? lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            parsedPoints.add([lat, lng]);
          }
        }
      }
    }
    return Zone(
      id: json['id'] ?? json['ID'],
      name: json['name'] ?? json['Name'] ?? '',
      vehicleTypeId: json['vehicle_TypeID'] ?? json['Vehicle_TypeID'] ?? json['vehicleTypeId'] ?? 0,
      points: parsedPoints,
    );
  }
}