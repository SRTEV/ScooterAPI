import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseHelper {
  static ConnectionSettings get settings {
    return ConnectionSettings(
      host: dotenv.env['DB_HOST']!,
      port: int.parse(dotenv.env['DB_PORT']!),
      user: dotenv.env['DB_USER']! ,
      password: dotenv.env['DB_PASSWORD']! ,
      db: dotenv.env['DB_NAME']!,
    );
  }

  static Future<void> connectToDatabase() async {
    try {
      final conn = await MySqlConnection.connect(settings);
      debugPrint("Connected successfully to MySQL!");
      await conn.close();
    } catch (e) {
      debugPrint("Database error (connect): $e");
    }
  }

  static Future<void> insertTelemetry(String QrCode, double battery, double x, double y) async {
    MySqlConnection? conn;
    try {
      conn = await MySqlConnection.connect(settings);
      await conn.query(
          'INSERT INTO Vehicle (battery_level, position_x, position_y, QR_code ,Vehicle_TypeID, Vechicle_StatusID) VALUES (?, ?, ?, ?, ?, ?)',
          [battery.toInt(), x, y,QrCode, 1, 1]
      );

      debugPrint("Telemetry inserted successfully!");
    } catch (e) {
      debugPrint("Database error (insert): $e");
    } finally {
      await conn?.close();
    }
  }
}
