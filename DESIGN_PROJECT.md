# Design Project Technical Foundation

## Project Title

**Modüler Ağırlık Tabanlı IoT Stok ve Envanter İzleme Platformu**

**Modular Weight-Based IoT Stock and Inventory Monitoring Platform**

## Objective

The project aims to provide a reusable IoT platform that estimates the number
of products at a monitored location from weight measurements. It is designed
for products whose unit weight is known or can be measured during setup. The
platform preserves a simple physical chain—load cell, HX711, ESP32, Firebase,
and a Flutter mobile application—so that new inventory scenarios can be added
without redesigning the complete system.

## Motivation

Manual stock counting is slow, error-prone, and difficult to perform
continuously. Camera-based systems can introduce cost, lighting, privacy, and
image-processing constraints. A weight-based platform offers a comparatively
low-cost alternative for packaged or countable items with consistent unit
weights. The same electronics and software can be reused for retail shelves,
warehouse bins, maintenance supplies, and other inventory points.

## Hardware Architecture

The retained hardware architecture is:

```text
Product load
    ↓
Load Cell
    ↓ analog bridge signal
HX711 amplifier and ADC
    ↓ digital measurement
ESP32
    ↓ Wi-Fi / BLE setup
Firebase Firestore
```

The current firmware supports two HX711 channels (`platform1` and
`platform2`). It averages ten HX711 samples per reading, prevents negative
reported weights, and publishes approximately every 30 seconds. BLE is used
for user association, tare, and reference-weight calibration. Calibration
factors are stored in ESP32 non-volatile preferences.

## Software Architecture

### ESP32 firmware

The firmware reads each load cell through HX711, applies the calibrated scale
factor, and patches only the measured weight and update timestamp in the
corresponding Firestore document. This prevents sensor uploads from
overwriting product metadata configured by the application.

### Firebase

Firebase Authentication identifies the mobile user. Firestore stores user
profiles, inventory-platform documents, and an optional restocking list. The
existing `platforms` collection name is retained for compatibility with
deployed firmware; in the generalized domain, every platform document is a
product measurement point.

```text
users/{uid}/platforms/{platformId}
  name: string
  category: string
  current_weight_kg: number
  unit_weight_kg: number | null
  minimum_stock_threshold: number | null
  status: "active" | "inactive"
  last_updated: timestamp
  configuration_updated_at: timestamp
```

### Mobile application

The Flutter application authenticates users, listens to platform documents in
real time, displays current weight and estimated quantity, identifies low
stock when a threshold is configured, edits product configuration, manages a
restocking list, and sends setup/calibration commands over BLE.

## Data Flow

```text
Load Cell → HX711 → ESP32 → Firebase Firestore → Flutter Mobile Application
```

1. Product weight deforms the load cell.
2. HX711 amplifies and digitizes the bridge output.
3. ESP32 averages samples and converts the reading with the calibration factor.
4. ESP32 updates `current_weight_kg` and `last_updated` in Firestore.
5. The mobile application receives the Firestore snapshot in real time.
6. The application derives quantity and stock status from the measurement and
   product configuration.

## Inventory Estimation Logic

For a configured product:

```text
estimatedQuantity = round(max(0, currentWeight) / unitWeight)
```

`currentWeight` and `unitWeight` use kilograms in storage. The UI accepts unit
weight in grams and converts it to kilograms. Measurements with an absolute
value below 0.005 kg are treated as zero to reduce false counts around an empty
platform. Nearest-integer rounding reduces systematic undercounting caused by
minor sensor drift. No estimate is produced when unit weight is missing or
non-positive.

If `minimum_stock_threshold` is configured, the application reports low stock
when `estimatedQuantity <= minimumStockThreshold`. This remains an estimate:
load-cell accuracy, calibration quality, packaging variation, shelf contact,
and external forces affect the result.

## Example Applications

- Counting brake cleaner spray cans on an automotive-parts store shelf.
- Monitoring packaged fasteners or maintenance consumables in warehouse bins.
- Tracking retail products that have a stable unit weight.
- Estimating office, laboratory, or workshop supplies.
- Monitoring refillable production-line material stations.

These are examples; the platform is not tied to one product category.

## Current Features

- Two load-cell/HX711 measurement channels.
- ESP32 Wi-Fi upload to Firestore.
- BLE device association, tare, and per-platform reference calibration.
- Persistent ESP32 calibration factors.
- Firebase Authentication and per-user inventory data.
- Real-time product weight display.
- Configurable product name, category, unit weight, and minimum stock threshold.
- Noise-aware estimated quantity and stock status.
- Active-platform dashboard with low-stock and stale-sensor summaries.
- One-tap, duplicate-safe transfer of low-stock products to the restocking list.
- General-purpose restocking list with pending-first ordering.
- English, Turkish, and German mobile localization.
- Light/dark theme selection.

## Possible Future Improvements

- Add hysteresis or time-window filtering for more stable stock alerts.
- Store measurement history for consumption and replenishment analytics.
- Generate push notifications when stock crosses its threshold.
- Support dynamic ESP32 Wi-Fi provisioning entirely through the mobile app.
- Add more sensor nodes and automatic device/platform discovery.
- Add calibration validation, diagnostics, and sensor health monitoring.
- Add role-based access for multi-user stores and warehouses.
- Evaluate accuracy experimentally across product types and environmental
  conditions.
- Add offline caching and conflict handling in the mobile application.
