#include <Arduino.h>
#include <esp_system.h>
#include <esp_arduino_version.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "HX711.h"
#include <time.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLESecurity.h>

// Firebase API keys identify the Firebase project; they are not credentials.
// Restrict this key to the required Firebase APIs in Google Cloud Console.
#define API_KEY "AIzaSyAMHeRwya8gQiK7-5u1557chofAv-gZTWk"
#define FIREBASE_PROJECT_ID "smart-kuehlschrank81"

#define SCK_PIN 6
#define P1_DOUT 4
#define P2_DOUT 5
#define PAIRING_BUTTON_PIN 0
#define SEND_INTERVAL_MS 30000UL

#define BLE_SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHARACTERISTIC_UUID_ID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
Preferences preferences;
HX711 scale1;
HX711 scale2;

String userId = "";
String deviceEmail = "";
String devicePassword = "";
String pairingDeviceId = "";
float CAL1 = 420.0;
float CAL2 = 420.0;
unsigned long lastSendTime = 0;
bool firebaseConfigured = false;
bool provisioningAllowed = false;
bool restartRequested = false;
uint32_t pairingPin = 0;

void connectWiFiWithAssembly(const String &ssid, const String &pass) {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());
  Serial.print("Connecting to WiFi");

  int counter = 0;
  while (WiFi.status() != WL_CONNECTED && counter < 20) {
    delay(500);
    Serial.print(".");
    asm volatile (
      "addi %0, %0, 1"
      : "+r"(counter)
    );
  }
  Serial.println();
}

String getOrCreatePairingDeviceId() {
  String value = preferences.getString("pairing_id", "");
  if (value.length() == 32) return value;

  uint8_t randomBytes[16];
  esp_fill_random(randomBytes, sizeof(randomBytes));
  const char hex[] = "0123456789ABCDEF";
  value.reserve(32);
  for (size_t i = 0; i < sizeof(randomBytes); i++) {
    value += hex[randomBytes[i] >> 4];
    value += hex[randomBytes[i] & 0x0F];
  }
  preferences.putString("pairing_id", value);
  return value;
}

uint32_t getOrCreatePairingPin() {
  uint32_t value = preferences.getUInt("pairing_pin", 0);
  if (value >= 100000 && value <= 999999) return value;
  value = 100000 + (esp_random() % 900000);
  preferences.putUInt("pairing_pin", value);
  return value;
}

void rotatePairingPin() {
  const uint32_t nextPin = 100000 + (esp_random() % 900000);
  preferences.putUInt("pairing_pin", nextPin);
}

bool isSafeCredentialValue(const String &value, size_t minLength, size_t maxLength) {
  if (value.length() < minLength || value.length() > maxLength) return false;
  for (size_t i = 0; i < value.length(); i++) {
    const char c = value.charAt(i);
    const bool allowed =
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-' || c == '_' || c == '.' || c == '@' || c == '~';
    if (!allowed) return false;
  }
  return true;
}

bool storeProvisioningCommand(const String &data) {
  if (!provisioningAllowed || !data.startsWith("PROVISION|")) return false;

  const int ownerEnd = data.indexOf('|', 10);
  const int emailEnd = ownerEnd < 0 ? -1 : data.indexOf('|', ownerEnd + 1);
  if (ownerEnd < 0 || emailEnd < 0 || data.indexOf('|', emailEnd + 1) >= 0) {
    return false;
  }

  const String nextOwner = data.substring(10, ownerEnd);
  const String nextEmail = data.substring(ownerEnd + 1, emailEnd);
  const String nextPassword = data.substring(emailEnd + 1);
  String expectedEmail = "device-" + pairingDeviceId;
  expectedEmail.toLowerCase();
  expectedEmail += "@devices.smart-inventory.invalid";
  if (!isSafeCredentialValue(nextOwner, 1, 128) ||
      !isSafeCredentialValue(nextEmail, 10, 254) ||
      nextEmail != expectedEmail ||
      (!userId.isEmpty() && nextOwner != userId) ||
      !isSafeCredentialValue(nextPassword, 32, 128)) {
    return false;
  }

  preferences.putString("user_id", nextOwner);
  preferences.putString("device_email", nextEmail);
  preferences.putString("device_pass", nextPassword);
  userId = nextOwner;
  deviceEmail = nextEmail;
  devicePassword = nextPassword;
  rotatePairingPin();
  provisioningAllowed = false;
  restartRequested = true;
  return true;
}

class SecureWriteCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    String data = characteristic->getValue();
#else
    const std::string rawValue = characteristic->getValue();
    String data = "";
    data.reserve(rawValue.length());
    for (const char c : rawValue) data += c;
#endif
    if (data.length() == 0 || data.length() > 500) return;
    data.trim();

    asm volatile("nop; nop;");

    if (data.startsWith("PROVISION|")) {
      storeProvisioningCommand(data);
      return;
    }
    if (userId.isEmpty()) return;

    if (data == "CAL:ZERO") {
      scale1.tare();
      scale2.tare();
    } else if (data.startsWith("CAL:P1:")) {
      const float referenceKg = data.substring(7).toFloat() / 1000.0;
      if (referenceKg > 0 && referenceKg <= 100) {
        const float factor = scale1.get_value(10) / referenceKg;
        if (isfinite(factor) && factor != 0) {
          CAL1 = factor;
          scale1.set_scale(CAL1);
          preferences.putFloat("cal1", CAL1);
        }
      }
    } else if (data.startsWith("CAL:P2:")) {
      const float referenceKg = data.substring(7).toFloat() / 1000.0;
      if (referenceKg > 0 && referenceKg <= 100) {
        const float factor = scale2.get_value(10) / referenceKg;
        if (isfinite(factor) && factor != 0) {
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
#if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 3, 0)
  BLESecurity::setEncryptionLevel(ESP_BLE_SEC_ENCRYPT_MITM);
#else
  BLEDevice::setEncryptionLevel(ESP_BLE_SEC_ENCRYPT_MITM);
#endif

  BLESecurity *security = new BLESecurity();
  security->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_MITM_BOND);
  security->setCapability(ESP_IO_CAP_OUT);
#if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 3, 0)
  security->setPassKey(true, pairingPin);
#else
  security->setStaticPIN(pairingPin);
#endif

  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(BLE_SERVICE_UUID);

  BLECharacteristic *writeCharacteristic = service->createCharacteristic(
    BLE_CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );
  writeCharacteristic->setAccessPermissions(ESP_GATT_PERM_WRITE_ENC_MITM);
  writeCharacteristic->setCallbacks(new SecureWriteCallbacks());

  BLECharacteristic *identityCharacteristic = service->createCharacteristic(
    BLE_CHARACTERISTIC_UUID_ID,
    BLECharacteristic::PROPERTY_READ
  );
  identityCharacteristic->setAccessPermissions(ESP_GATT_PERM_READ_ENC_MITM);
  identityCharacteristic->setValue(("DEVICE:" + pairingDeviceId).c_str());

  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();
}

int assemblyAdd(int a, int b) {
  int result;
  asm volatile (
    "add %0, %1, %2"
    : "=r"(result)
    : "r"(a), "r"(b)
  );
  return result;
}

bool getTimestamp(String &timestamp) {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo, 5000)) return false;
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  timestamp = String(buffer);
  return true;
}

void sendData(const String &platformId, float weight) {
  if (!firebaseConfigured || !Firebase.ready() || !isfinite(weight)) return;

  String timestamp;
  if (!getTimestamp(timestamp)) return;

  const int dummy = assemblyAdd(5, 10);
  (void)dummy;
  const String json =
    "{\"fields\":{\"current_weight_kg\":{\"doubleValue\":" +
    String(weight, 2) +
    "},\"last_updated\":{\"timestampValue\":\"" + timestamp + "\"}}}";
  const String path = "users/" + userId + "/platforms/" + platformId;

  Firebase.Firestore.patchDocument(
    &fbdo,
    FIREBASE_PROJECT_ID,
    "",
    path.c_str(),
    json.c_str(),
    "current_weight_kg,last_updated"
  );
}

void setup() {
  Serial.begin(115200);
  pinMode(PAIRING_BUTTON_PIN, INPUT_PULLUP);
  preferences.begin("smart-fridge", false);

  pairingDeviceId = getOrCreatePairingDeviceId();
  pairingPin = getOrCreatePairingPin();
  userId = preferences.getString("user_id", "");
  deviceEmail = preferences.getString("device_email", "");
  devicePassword = preferences.getString("device_pass", "");
  provisioningAllowed =
    userId.isEmpty() ||
    deviceEmail.isEmpty() ||
    devicePassword.isEmpty() ||
    digitalRead(PAIRING_BUTTON_PIN) == LOW;

  if (provisioningAllowed) {
    Serial.printf("BLE pairing code: %06u\n", pairingPin);
  }

  setupBLE();

  scale1.begin(P1_DOUT, SCK_PIN);
  scale2.begin(P2_DOUT, SCK_PIN);
  CAL1 = preferences.getFloat("cal1", CAL1);
  CAL2 = preferences.getFloat("cal2", CAL2);
  scale1.set_scale(CAL1);
  scale2.set_scale(CAL2);

  const String ssid = preferences.getString("wifi_ssid", "");
  const String wifiPassword = preferences.getString("wifi_pass", "");
  if (!ssid.isEmpty()) connectWiFiWithAssembly(ssid, wifiPassword);

  if (!userId.isEmpty() && !deviceEmail.isEmpty() && !devicePassword.isEmpty()) {
    configTime(0, 0, "pool.ntp.org", "time.google.com");
    config.api_key = API_KEY;
    auth.user.email = deviceEmail.c_str();
    auth.user.password = devicePassword.c_str();
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    firebaseConfigured = true;
  }

  lastSendTime = millis() - SEND_INTERVAL_MS;
}

void loop() {
  if (restartRequested) {
    delay(500);
    ESP.restart();
  }

  if (firebaseConfigured && millis() - lastSendTime > SEND_INTERVAL_MS) {
    float weight1 = scale1.get_units(10);
    float weight2 = scale2.get_units(10);
    if (!isfinite(weight1) || weight1 < 0) weight1 = 0;
    if (!isfinite(weight2) || weight2 < 0) weight2 = 0;

    sendData("platform1", weight1);
    sendData("platform2", weight2);
    lastSendTime = millis();
  }
}
