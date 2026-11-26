# ScooterAPI – vehicle simulator

Flutter application that simulates the on-board device of a rental vehicle (scooter, bike, monowheel) for the Transport rental system. It plays the role of the IoT module: it reads the vehicle state from the backend, sends GPS telemetry during a ride and locks or unlocks the vehicle.

## Features

- **Vehicle selection** by type and QR code.
- **Telemetry** – GPS position, battery level and speed sent every 5 s while the vehicle is unlocked.
- **Device authentication** – every telemetry request is signed with HMAC-SHA256 using the vehicle device key; the server response is signed too and verified by the simulator.
- **Lock / unlock by status** – the vehicle is unlocked only in status `Rented` (ride) or `InService` (technician service mode). Any other status locks it (speed 0).
- **Lock confirmation** – after locking, the simulator sends a signed message with `locked: true` and retries every 5 s until the server accepts it.
- **Zones** – in a red zone the maximum speed is set to 0.
- **Fail-safe** – if the server does not respond for 30 s, the vehicle locks itself (`NO CONNECTION - LOCKED`), buffers telemetry points and resends them after reconnecting.

## Requirements

- Flutter SDK (Dart 3)
- Running TransportApi backend (WebBackend)
- Android emulator or device with location enabled

## Run

```
flutter pub get
flutter run
```

## Project structure

- `lib/main.dart` – UI (control panel, vehicle state, lock modes)
- `lib/Controller.dart` – simulation logic: status polling, telemetry loop, locking, fail-safe, buffer
- `lib/db.dart` – API client and request signing
- `lib/models.dart` – data models
