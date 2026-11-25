import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';

// Wynik wysłania telemetrii (do wyświetlenia stanu połączenia w panelu symulatora)
enum TelemetryResult { ok, noDeviceKey, unauthorized, serverNotVerified, error }

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

  // Klucz urządzenia (Base64) wydany przez administratora: POST /api/Vehicle (jednorazowo) lub /api/Vehicle/device-key/{id}
  static List<int>? get _deviceKey {
    final raw = dotenv.env['DEVICE_KEY'];
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return base64.decode(raw.trim());
    } catch (_) {
      return null;
    }
  }

  static List<int> _hmac(List<int> key, List<int> data) => Hmac(sha256, key).convert(data).bytes;

  // Porównanie w stałym czasie
  static bool _equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // Dwustronne uwierzytelnianie HMAC-SHA256:
  //  - urządzenie podpisuje treść żądania swoim kluczem (nagłówek X-Signature),
  //  - serwer podpisuje treść odpowiedzi tym samym kluczem (X-Server-Signature), a urządzenie to weryfikuje.
  static Future<TelemetryResult> sendTelemetry(String qrCode, double battery, double x, double y, double speed) async {
    final key = _deviceKey;
    if (key == null) return TelemetryResult.noDeviceKey;

    // Podpisywany jest dokładnie ten tekst, który zostaje wysłany
    final body = json.encode({
      'qrCode': qrCode,
      'battery': battery,
      'x': x,
      'y': y,
      'speed': speed,
    });
    final signature = base64.encode(_hmac(key, utf8.encode(body)));

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Vehicle/telemetry'),
        headers: {
          'Content-Type': 'application/json',
          'X-Signature': signature,
        },
        body: body,
      );

      if (response.statusCode == 401) return TelemetryResult.unauthorized;
      if (response.statusCode != 200) return TelemetryResult.error;

      final serverSignature = response.headers['x-server-signature'];
      if (serverSignature == null) return TelemetryResult.serverNotVerified;

      List<int> provided;
      try {
        provided = base64.decode(serverSignature);
      } catch (_) {
        return TelemetryResult.serverNotVerified;
      }

      final expected = _hmac(key, response.bodyBytes);
      return _equals(provided, expected) ? TelemetryResult.ok : TelemetryResult.serverNotVerified;
    } catch (e) {
      print("Error sending telemetry: $e");
      return TelemetryResult.error;
    }
  }
}