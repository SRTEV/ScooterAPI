import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Controller.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    ChangeNotifierProvider(
      create: (_) => ScooterViewModel(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ScooterControlPanel(),
      ),
    ),
  );
}

class ScooterControlPanel extends StatelessWidget {
  const ScooterControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scooter API Control Panel')),
      body: Consumer<ScooterViewModel>(
        builder: (context, vm, child) => SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Select Vehicle Type:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<VehicleType>(
                isExpanded: true,
                value: vm.selectedType,
                hint: const Text('Choose Type'),
                items: vm.vehicleTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type.name));
                }).toList(),
                onChanged: vm.selectVehicleType,
              ),
              const SizedBox(height: 10),

              const Text('2. Select Specific Vehicle:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<Vehicle>(
                isExpanded: true,
                value: vm.selectedVehicle,
                hint: const Text('Choose Vehicle'),
                items: vm.filteredVehicles.map((v) {
                  return DropdownMenuItem(value: v, child: Text('${v.model} (QR: ${v.qrCode})'));
                }).toList(),
                onChanged: vm.selectVehicle,
              ),
              const SizedBox(height: 10),

              const Text('3. Vehicle Status (Rental Control):', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<VehicleStatus>(
                isExpanded: true,
                value: vm.selectedStatus,
                hint: const Text('Choose Status'),
                items: vm.statuses.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status.name));
                }).toList(),
                onChanged: vm.selectedVehicle != null ? vm.updateStatus : null,
              ),
              const SizedBox(height: 15),

              if (vm.isInRedZone)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'RED ZONE WARNING! Speed is restricted to 0 km/h.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Speed: ${vm.speed.toStringAsFixed(1)} km/h (Max: ${vm.maxAllowedSpeed.toInt()})',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: vm.isRented ? Colors.black : Colors.grey,
                ),
              ),
              Slider(
                value: vm.speed,
                max: vm.maxAllowedSpeed > 0 ? vm.maxAllowedSpeed : 1.0,
                onChanged: (vm.isRented && vm.maxAllowedSpeed > 0) ? vm.updateSpeed : null,
              ),

              Text('Battery: ${vm.battery.toInt()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(value: vm.battery, max: 100, onChanged: vm.updateBattery),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: vm.isInRedZone ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: vm.isInRedZone ? Colors.red : Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${vm.locationStatus}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Latitude (X): ${vm.x.toStringAsFixed(6)}'),
                    Text('Longitude (Y): ${vm.y.toStringAsFixed(6)}'),
                    Text(
                      'Mode: ${vm.isRented ? "RENTED (Telemetry Active)" : "LOCKED"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: vm.isRented ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}