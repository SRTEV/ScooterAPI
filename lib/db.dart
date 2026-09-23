import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';

  static Future<List<VehicleType>> getVehicleTypes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/VehicleType'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((e) => VehicleType.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching types: $e");
    }
    return [];
  }

  static Future<List<Vehicle>> getVehicles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Vehicle'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((e) => Vehicle.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching vehicles: $e");
    }
    return [];
  }

  static Future<List<Zone>> getZones() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Zone'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((e) => Zone.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching zones: $e");
    }
    return [];
  }

  static Future<bool> sendTelemetry(String qrCode, double battery, double x, double y, double speed) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Vehicle/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'qrCode': qrCode,
          'battery': battery,
          'x': x,
          'y': y,
          'speed': speed,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error sending telemetry: $e");
      return false;
    }
  }
}