import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'Controller.dart';

void main() => runApp(
  ChangeNotifierProvider(
    create: (_) => ScooterViewModel(),
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScooterControlPanel(),

    ),
  ),
);

class ScooterControlPanel extends StatelessWidget {
  const ScooterControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scooter API')),
      body: Consumer<ScooterViewModel>(
        builder: (context, vm, child) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text('Speed: ${vm.speed.toStringAsFixed(1)} km/h'
                , style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
              Slider(value: vm.speed, max: 20, onChanged: vm.updateSpeed),

              Text('Battery: ${vm.battery.toInt()} %', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Slider(value: vm.battery, max: 100, onChanged: vm.updateBattery),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Status: ${vm.locationStatus}'),
                    Text('X (Lat): ${vm.latitude.toStringAsFixed(6)}'),
                    Text('Y (Lon): ${vm.longitude.toStringAsFixed(6)}'),
                  ],
                ),
              ),

              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: vm.isSimulating ? Colors.red[300] : Colors.green[300],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: vm.toggleSimulation,
                child: Text(
                  vm.isSimulating ? 'Stop Telemetry' : 'Start Telemetry',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}