/**
 * classroom_beacon.ino
 * 
 * ESP32 iBeacon transmitter for the Cheat-Proof Indoor Attendance System.
 * 
 * Each classroom gets one ESP32 running this firmware with a unique UUID.
 * The BLE signal power is deliberately reduced so it does not penetrate
 * through walls, ensuring students must be physically inside the room.
 * 
 * Hardware: ESP32 (any variant with BLE support)
 * Library:  NimBLE-Arduino (install via Arduino Library Manager)
 */

#include <NimBLEDevice.h>
#include <NimBLEBeacon.h>

// ─── Classroom Identity ───────────────────────────────────────────────────────
// Generate a unique UUID for each classroom via https://www.uuidgenerator.net/
// This must match AppConstants.targetBeaconUUID in the Flutter app.
#define BEACON_UUID    "B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define BUILDING_ID    1     // Major: identifies the building
#define ROOM_NUMBER    101   // Minor: identifies the specific classroom

// ─── BLE Power Configuration ──────────────────────────────────────────────────
// ESP_PWR_LVL_N12 (-12 dBm): Recommended starting point.
// If signal leaks into the hallway, reduce to ESP_PWR_LVL_N21 (-21 dBm).
// Options: ESP_PWR_LVL_N12, ESP_PWR_LVL_N21, ESP_PWR_LVL_N15, ESP_PWR_LVL_N9
#define TX_POWER       ESP_PWR_LVL_N12

// RSSI at exactly 1 meter from the beacon (calibrate by measuring in-room).
// Used by mobile devices to estimate proximity. Typical value: -55 to -65 dBm.
#define CALIBRATED_RSSI_AT_1M  -59

void setup() {
  Serial.begin(115200);
  Serial.println("Initializing ESP32 Classroom Beacon...");

  NimBLEDevice::init("");
  NimBLEDevice::setPower(TX_POWER);

  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

  NimBLEBeacon iBeacon;
  // 0x004C = Apple iBeacon Manufacturer ID (required for standard iBeacon detection)
  iBeacon.setManufacturerId(0x004C);
  iBeacon.setProximityUUID(NimBLEUUID(BEACON_UUID));
  iBeacon.setMajor(BUILDING_ID);
  iBeacon.setMinor(ROOM_NUMBER);
  iBeacon.setSignalPower(CALIBRATED_RSSI_AT_1M);

  NimBLEAdvertisementData advertisementData;
  // 0x04 = BR_EDR_NOT_SUPPORTED (BLE only, not classic Bluetooth)
  advertisementData.setFlags(0x04);

  // Pack the iBeacon data into the advertisement payload
  std::string strServiceData = "";
  strServiceData += (char)26;    // Length byte
  strServiceData += (char)0xFF;  // Type: Manufacturer Specific Data
  strServiceData += iBeacon.getData();

  advertisementData.addData(strServiceData);
  pAdvertising->setAdvertisementData(advertisementData);
  pAdvertising->start();

  Serial.printf("Beacon active | UUID: %s | Building: %d | Room: %d\n",
                BEACON_UUID, BUILDING_ID, ROOM_NUMBER);
  Serial.printf("TX Power: %d | Calibrated RSSI@1m: %d dBm\n",
                TX_POWER, CALIBRATED_RSSI_AT_1M);
}

void loop() {
  // Advertising runs entirely in the NimBLE background task.
  // The main loop only needs to keep the device alive.
  delay(10000);
}
