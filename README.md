# Modular Weight-Based IoT Stock and Inventory Monitoring Platform

## Project Overview

This repository contains a general-purpose IoT platform for monitoring stock
by weight. A product is assigned to a weighing platform, its current weight is
measured, and its approximate quantity is calculated from a known or calibrated
unit weight. The system is intended for Erciyes University Computer Engineering
Design Project work and is not tied to refrigerators, food, or a single retail
domain.

The project generalizes the original working application while retaining its
core hardware and software architecture: load cells, HX711, ESP32, Firebase,
and Flutter.

## Problem

Manual inventory counts provide only occasional snapshots, consume staff time,
and are vulnerable to counting mistakes. Many small businesses and warehouses
need a low-cost way to observe countable packaged products without replacing
their existing shelving or deploying a camera system.

## Solution

Each monitored product position uses a load cell and HX711. The ESP32 publishes
the measured weight to Firebase Firestore. The mobile application listens for
updates, displays the live weight, and estimates item count using the configured
unit weight. An optional minimum-stock threshold provides an immediate stock
status.

## System Architecture

```text
Load Cell → HX711 → ESP32 → Firebase Firestore → Mobile Application
```

- **Load Cell:** converts the applied product load into an electrical signal.
- **HX711:** amplifies and digitizes the load-cell signal.
- **ESP32:** averages measurements, applies calibration, and uploads weights.
- **Firebase:** provides authentication and real-time per-user data storage.
- **Flutter application:** configures products and displays weight, estimated
  quantity, stock status, restocking data, and calibration controls.

## Hardware

- ESP32 development board
- Load cells
- HX711 load-cell amplifier/ADC modules
- Stable weighing platforms or shelf modules
- Known reference weight for calibration (the current UI uses 800 g)
- Wi-Fi network and BLE-capable mobile device

The current firmware has two sensor inputs and publishes them as `platform1`
and `platform2`. It reads ten samples per channel and publishes every 30 seconds.

## Software

- Arduino/ESP32 firmware
- HX711 and Firebase ESP Client Arduino libraries
- Flutter mobile and desktop application
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Function for initial user data

No application ID or deployed Firebase project identity was renamed during the
domain conversion, avoiding unnecessary configuration and deployment breakage.

## Data Flow

1. A product load is measured by a load cell through HX711.
2. The ESP32 averages samples and applies the platform calibration factor.
3. Negative readings are clamped to zero.
4. The ESP32 patches `current_weight_kg` and `last_updated` in Firestore.
5. The Flutter application receives real-time Firestore snapshots.
6. If `unit_weight_kg` is configured, the application estimates quantity:

   ```text
   estimatedQuantity ≈ currentWeight / unitWeight
   ```

7. Values within 0.005 kg of zero are treated as sensor noise, and the result is
   rounded to the nearest whole item.
8. If a minimum threshold is configured, the app shows whether stock is low.

### Firestore model

The existing collection path is deliberately retained for firmware
compatibility:

```text
users/{uid}/platforms/{platformId}
  name
  category
  current_weight_kg
  unit_weight_kg
  minimum_stock_threshold
  status
  last_updated
  configuration_updated_at
```

`estimatedQuantity` is derived in the mobile application instead of being
stored, so it cannot become stale when a sensor update arrives. The model also
accepts legacy weight field names while existing documents are migrated through
normal editing.

## Example Use Cases

- An automotive-parts store monitors how many brake cleaner spray cans remain
  on a shelf.
- A warehouse tracks packaged products or boxes of fasteners in storage bins.
- A retailer uses the same platform for multiple product categories.
- A workshop tracks consumables with stable unit weights.
- A business monitors refill levels at modular supply stations.

The brake cleaner example demonstrates count-by-weight; it does not limit the
platform to automotive inventory.

## Repository Structure

```text
Arduino/smart_kuehlschrank_esp32.ino/esp32.ino  ESP32/HX711/BLE firmware
lib/models/                                     Inventory and app models
lib/services/                                   Firebase and device services
lib/screens/                                    Flutter application screens
lib/l10n/                                       English, Turkish, German text
functions/                                      Firebase Cloud Function
test/                                           Inventory estimation tests
DESIGN_PROJECT.md                               Academic/technical foundation
```

The legacy firmware folder name and Dart package name are retained to avoid
breaking tooling and imports; they do not represent the platform's current
domain.

## Setup / Running

### Firebase

1. Use the existing Firebase project configuration or connect your own project.
2. Enable Firebase Authentication and Cloud Firestore.
3. Keep credentials in the existing local/generated configuration locations.
   Do not place secret values in documentation, logs, or commits.
4. To initialize new-user product slots, install dependencies in `functions/`
   and deploy `createUserProfile` through your normal Firebase workflow.

### Flutter application

```bash
flutter pub get
flutter gen-l10n
flutter run
```

Sign in, open **Account → Inventory Device Setup** to associate the ESP32 user,
then open **Calibration** to tare and calibrate the two weighing platforms.
Configure each product's name, category, unit weight, and optional minimum-stock
threshold from the inventory screen.

### ESP32 firmware

1. Open `Arduino/smart_kuehlschrank_esp32.ino/esp32.ino` in Arduino IDE or a
   compatible ESP32 build environment.
2. Install the board support and required WiFi, Firebase ESP Client, HX711, BLE,
   and Preferences libraries.
3. Configure the existing network/Firebase authentication mechanism locally;
   never publish its credential values.
4. Select the correct ESP32 target and port, compile, and upload.
5. Pair the device in the app and run tare/reference calibration.

## Future Improvements

- Time-window filtering and hysteresis for stock-state transitions.
- Measurement history, usage trends, and replenishment forecasts.
- Push notifications for threshold crossings.
- Full BLE-based Wi-Fi provisioning.
- More sensor modules and automatic platform discovery.
- Multi-user organization and role support.
- Calibration diagnostics and sensor-fault detection.
- Offline mobile caching and synchronization.

More detailed technical and academic context is available in
[`DESIGN_PROJECT.md`](DESIGN_PROJECT.md).
