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

  static Future<void> insertTelemetry(String qrCode, double battery, double x, double y, double speed) async {
    MySqlConnection? conn;
    try {
      conn = await MySqlConnection.connect(settings);

      await conn.query(
        '''
        UPDATE Vehicle 
        SET Battery_level = ?, Position_X = ?, Position_Y = ?, Last_activity = NOW() 
        WHERE QR_code = ?
        ''',
        [battery.toInt(), x, y, qrCode]
      );

      var result = await conn.query(
        '''
        INSERT INTO Route_History (VehicleID, Position_X, Position_Y, Battery_level, Speed)
        SELECT ID, ?, ?, ?, ? FROM Vehicle WHERE QR_code = ?
        ''',
        [x, y, battery.toInt(), speed, qrCode]
      );

      if (result.affectedRows == 0) {
        debugPrint("Warning: No vehicle found with QR Code: $qrCode");
      } else {
        debugPrint("Telemetry & route updated!");
      }

    } catch (e) {
      debugPrint("Database error (insert/update): $e");
    } finally {
      await conn?.close();
    }
  }
}