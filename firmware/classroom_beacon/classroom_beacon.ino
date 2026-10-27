/**
 * classroom_beacon.ino (Refined & Optimized)
 * 
 * ESP32 iBeacon transmitter for the Cheat-Proof Indoor Attendance System.
 * 
 * Hardware: ESP32 (any variant with BLE support)
 * Library:  NimBLE-Arduino (install via Arduino Library Manager)
 */

#include <NimBLEDevice.h>
#include <NimBLEBeacon.h>

// ─── Classroom Identity Configuration ─────────────────────────────────────────
#define BEACON_UUID    "B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define BUILDING_ID    1     // Major
#define ROOM_NUMBER    101   // Minor

// ─── BLE Power & Calibration ──────────────────────────────────────────────────
// ESP_PWR_LVL_N12 (-12 dBm) restricts signal bleed through walls.
#define TX_POWER               ESP_PWR_LVL_N12 
#define CALIBRATED_RSSI_AT_1M  -59

// ─── Hardware Defines ─────────────────────────────────────────────────────────
#define ONBOARD_LED 2 // Most ESP32 dev boards use GPIO 2 for the built-in LED

void setup() {
  Serial.begin(115200);
  pinMode(ONBOARD_LED, OUTPUT);
  
  // Quick visual double-blink to confirm successful boot to the installer
  for(int i = 0; i < 2; i++) {
    digitalWrite(ONBOARD_LED, HIGH);
    delay(200);
    digitalWrite(ONBOARD_LED, LOW);
    delay(200);
  }

  Serial.println("\nInitializing Optimized ESP32 Classroom Beacon...");

  // 1. Initialize NimBLE stack
  NimBLEDevice::init("");
  NimBLEDevice::setPower(TX_POWER);

  // 2. Configure the iBeacon payload parameters
  NimBLEBeacon iBeacon;
  iBeacon.setManufacturerId(0x004C); // Apple Company ID
  iBeacon.setProximityUUID(NimBLEUUID(BEACON_UUID));
  iBeacon.setMajor(BUILDING_ID);
  iBeacon.setMinor(ROOM_NUMBER);
  iBeacon.setSignalPower(CALIBRATED_RSSI_AT_1M);

  // 3. Assemble the raw memory payload for NimBLE 1.4+ compatibility
  std::string beaconData = iBeacon.getData();
  uint8_t payload[27];
  payload[0] = 26;    // Overall length byte (1 byte type + 25 bytes beacon data)
  payload[1] = 0xFF;  // Type: Manufacturer Specific Data
  if (beaconData.length() <= 25) {
    memcpy(&payload[2], beaconData.data(), beaconData.length());
  }

  // 4. Configure Advertisement flags and attach payload
  NimBLEAdvertisementData advertisementData;
  advertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED (BLE only)
  advertisementData.addData(std::string((char*)payload, sizeof(payload)));

  // 5. Start Advertising with Standardized Intervals
  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->setAdvertisementData(advertisementData);
  
  // Standard iBeacon interval is 100ms (160 * 0.625ms = 100ms)
  // This ensures rapid detection by attendance apps
  pAdvertising->setMinInterval(160);
  pAdvertising->setMaxInterval(160);
  pAdvertising->start();

  Serial.printf("Beacon Active  | UUID: %s\n", BEACON_UUID);
  Serial.printf("Location Info  | Building: %d | Room: %d\n", BUILDING_ID, ROOM_NUMBER);
  Serial.printf("BLE Config     | TX Power: %d | RSSI@1m: %d dBm\n", TX_POWER, CALIBRATED_RSSI_AT_1M);
  Serial.println("Setup complete. BLE advertising running in background.");
}

void loop() {
  // Low-power yield: BLE advertising runs on a separate background FreeRTOS task.
  // vTaskDelay avoids busy-waiting while feeding the FreeRTOS Task Watchdog Timer.
  vTaskDelay(portMAX_DELAY);
}
