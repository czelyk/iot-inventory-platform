/************************************************************
 * PART 1 – AHMET
 * This part was implemented by Ahmet.
 * Responsibilities:
 * - Global configuration
 * - WiFi & Firebase initialization
 * - Assembly usage in WiFi connection logic
 ************************************************************/

#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "HX711.h"
#include <time.h>
#include <Preferences.h>

// ===== GLOBAL SETTINGS =====
#define API_KEY "AIzaSyAMHeRwya8gQiK7-5u1557chofAv-gZTWk"
#define FIREBASE_PROJECT_ID "smart-kuehlschrank81"

// --- HX711 Pins ---
#define SCK_PIN 6
#define P1_DOUT 4
#define P2_DOUT 5

#define SEND_INTERVAL_MS 30000UL

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

Preferences preferences;
String userId = "";
unsigned long lastSendTime = 0;

// ===== ASSEMBLY (Ahmet) =====
// Assembly is used to increment the WiFi retry counter manually
void connectWiFiWithAssembly(String ssid, String pass) {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());
  Serial.print("Connecting to WiFi: " + ssid);

  int counter = 0;
  while (WiFi.status() != WL_CONNECTED && counter < 20) {
    delay(500);
    Serial.print(".");

    // addi = add immediate (RISC-style)
    asm volatile (
      "addi %0, %0, 1"
      : "+r"(counter)
    );
  }
}

/************************************************************
 * PART 2 – TOBIAS
 * This part was implemented by Tobias.
 * Responsibilities:
 * - Bluetooth Low Energy (BLE)
 * - User configuration via BLE
 * - Sensor calibration logic
 ************************************************************/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define BLE_SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

HX711 scale1;
HX711 scale2;
float CAL1 = 420.0;
float CAL2 = 420.0;

// ===== BLE CALLBACKS (Tobias) =====
class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    String data = "";

    for (char c : value) data += c;
    data.trim();

    // Assembly used as a synchronization nop
    asm volatile("nop; nop;");

    if (data.startsWith("UID:")) {
      preferences.putString("user_id", data.substring(4));
    }
    else if (data == "CAL:ZERO") {
      scale1.tare();
      scale2.tare();
    }
    else if (data.startsWith("CAL:P1:")) {
      float referenceKg = data.substring(7).toFloat() / 1000.0;
      if (referenceKg > 0) {
        float factor = scale1.get_value(10) / referenceKg;
        if (factor != 0) {
          CAL1 = factor;
          scale1.set_scale(CAL1);
          preferences.putFloat("cal1", CAL1);
        }
      }
    }
    else if (data.startsWith("CAL:P2:")) {
      float referenceKg = data.substring(7).toFloat() / 1000.0;
      if (referenceKg > 0) {
        float factor = scale2.get_value(10) / referenceKg;
        if (factor != 0) {
          CAL2 = factor;
          scale2.set_scale(CAL2);
          preferences.putFloat("cal2", CAL2);
        }
      }
    }
  }
};

void setupBLE() {
  BLEDevice::init("Inventory Platform ESP32");
  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(BLE_SERVICE_UUID);

  BLECharacteristic *ch = service->createCharacteristic(
    BLE_CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );

  ch->setCallbacks(new MyCallbacks());
  service->start();
  BLEDevice::startAdvertising();
}

/************************************************************
 * PART 3 – LUCAS
 * This part was implemented by Lucas.
 * Responsibilities:
 * - Sensor reading
 * - Firebase data transmission
 * - Assembly arithmetic operations
 ************************************************************/

// ===== ASSEMBLY (Lucas) =====
// Simple arithmetic using registers
int assemblyAdd(int a, int b) {
  int result;
  asm volatile (
    "add %0, %1, %2"
    : "=r"(result)
    : "r"(a), "r"(b)
  );
  return result;
}

String getTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "2025-01-01T00:00:00Z";
  char buf[32];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buf);
}

void sendData(String id, float weight) {
  int dummy = assemblyAdd(5, 10); // Lucas' assembly function
  Serial.println("Assembly dummy result: " + String(dummy));

  String json =
    "{\"fields\":{\"current_weight_kg\":{\"doubleValue\":" + String(weight, 2) +
    "},\"last_updated\":{\"timestampValue\":\"" + getTimestamp() + "\"}}}";

  String path = "users/" + userId + "/platforms/" + id;

  Firebase.Firestore.patchDocument(
    &fbdo,
    FIREBASE_PROJECT_ID,
    "",
    path.c_str(),
    json.c_str(),
    "current_weight_kg,last_updated"
  );
}

/************************************************************
 * MAIN APPLICATION FLOW
 ************************************************************/

void setup() {
  Serial.begin(115200);
  // Keep the legacy namespace so existing WiFi and user pairing survives the
  // product-domain rebrand.
  preferences.begin("smart-fridge", false);

  userId = preferences.getString("user_id", "");
  String ssid = preferences.getString("wifi_ssid", "");
  String pass = preferences.getString("wifi_pass", "");

  setupBLE();

  scale1.begin(P1_DOUT, SCK_PIN);
  scale2.begin(P2_DOUT, SCK_PIN);
  CAL1 = preferences.getFloat("cal1", CAL1);
  CAL2 = preferences.getFloat("cal2", CAL2);
  scale1.set_scale(CAL1);
  scale2.set_scale(CAL2);

  if (ssid != "") {
    connectWiFiWithAssembly(ssid, pass);
  }

  configTime(0, 0, "pool.ntp.org");
  config.api_key = API_KEY;
  auth.user.email = "esp32@auth.com";
  auth.user.password = "esp32pass";

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  lastSendTime = millis() - SEND_INTERVAL_MS;
}

void loop() {
  if (millis() - lastSendTime > SEND_INTERVAL_MS) {
    float w1 = scale1.get_units(10);
    float w2 = scale2.get_units(10);

    if (w1 < 0) w1 = 0;
    if (w2 < 0) w2 = 0;

    sendData("platform1", w1);
    sendData("platform2", w2);

    lastSendTime = millis();
  }
}
