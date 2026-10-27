# ESP32 Classroom Beacon — Firmware README

This guide walks you through everything needed to flash the ESP32 iBeacon firmware for the Cheat-Proof Indoor Attendance System. Each classroom gets its own ESP32 unit broadcasting a **unique UUID** at reduced power so the signal does not bleed through walls.

---

## 🔄 Evolution & Changelog (Past State vs. Current State)

| Component / Area | Past State | Current State (Work Done & Improved) |
|---|---|---|
| **BLE Protocol Stack** | Legacy ESP32 Bluedroid stack consumed excessive RAM (~150KB) and flash memory. | **Migrated to `NimBLE-Arduino` (>= 1.4.0)**, cutting memory overhead by over 50%. |
| **RF Power & Wall Bleed** | Default TX power allowed beacon signals to bleed into corridors and adjacent classrooms. | **Tuned TX Power to `-12 dBm` (`ESP_PWR_LVL_N12`)** with -59 dBm 1m reference RSSI. |
| **In-Room RSSI Cutoff** | Thresholds were loosely documented. | **Synchronized Detection Threshold**: Flutter mobile client requires `RSSI > -70 dBm`; hallway reads `< -75 dBm` or undetectable. |
| **Payload Assembly** | String-based beacon encoding causing incompatibility across NimBLE versions. | **Standardized 27-byte Raw Memory Assembly** (`0x004C` Apple ID, UUID, Major, Minor, Calibrated RSSI). |
| **CPU Scheduling** | Busy-wait `delay()` loops risking Watchdog Timer (TWDT) resets. | **FreeRTOS Low-Power Yield** using `vTaskDelay(portMAX_DELAY)`. |
| **Field Diagnostics** | No visual confirmation of active boot/broadcasting. | **Boot Diagnostic Double-Blink** on GPIO 2 (onboard LED). |

---

## Hardware Requirements

| Item | Specification |
|------|--------------|
| **Microcontroller** | Any ESP32 variant with BLE (ESP32-WROOM-32, ESP32-S3, ESP32-C3, etc.) |
| **USB Cable** | Micro-USB or USB-C depending on the ESP32 board variant |
| **Power Supply** | 5V USB (phone charger, USB hub, or PC USB port) |
| **Computer** | Windows / macOS / Linux with a USB port |

> **No additional wiring is required.** The ESP32 runs entirely on USB 5V power. No sensors, no peripherals.

---

## Arduino IDE Setup

1. **Install Arduino IDE 2.x** from [https://www.arduino.cc/en/software](https://www.arduino.cc/en/software)

2. **Add the ESP32 Board Manager URL:**
   - Open `File → Preferences`
   - In the *Additional boards manager URLs* field, add:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```

3. **Install the ESP32 board package:**
   - Open `Tools → Board → Boards Manager`
   - Search for `esp32` by Espressif Systems
   - Install version **2.0.x** or later

4. **Select the correct board:**
   - `Tools → Board → ESP32 Arduino → ESP32 Dev Module`

5. **Configure upload settings:**
   | Setting | Value |
   |---------|-------|
   | Upload Speed | `921600` |
   | Flash Frequency | `80MHz` |
   | Flash Mode | `QIO` |
   | Partition Scheme | `Default 4MB with spiffs` |

---

## NimBLE-Arduino Library Installation

1. Open `Sketch → Include Library → Manage Libraries...`
2. Search for **NimBLE-Arduino**
3. Select the library by **h2zero**
4. Install version **1.4.0 or newer**

> **Why NimBLE?** The default Arduino ESP32 BLE library has known stability issues on some boards. NimBLE-Arduino is lighter, more reliable, and actively maintained.

---

## Setting a Unique UUID Per Classroom

Every classroom **must** have a different UUID. Using the same UUID in multiple rooms defeats the proximity check.

### Step 1 — Generate a UUID

Visit [https://www.uuidgenerator.net/](https://www.uuidgenerator.net/) and click *Generate*. Copy the result.

### Step 2 — Edit the firmware constants

Open `classroom_beacon.ino` and update the three identity constants at the top:

```cpp
// ─── Classroom Identity ───────────────────────────────────────────────────────
#define BEACON_UUID    "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"  // ← paste new UUID
#define BUILDING_ID    1     // Major: building number (1, 2, 3…)
#define ROOM_NUMBER    101   // Minor: room number (101, 102, 203…)
```

### Step 3 — Record it in the UUID registry

Keep a spreadsheet mapping each ESP32's physical location to its UUID. This UUID must also be added to the Flutter app's `AppConstants.targetBeaconUUID` for the matching classroom.

### UUID Registry Template

| Location | UUID | BUILDING_ID | ROOM_NUMBER | Flash Date |
|----------|------|-------------|-------------|------------|
| Bldg A, Room 101 | B9407F30-... | 1 | 101 | 2024-01-15 |
| Bldg A, Room 102 | C3A1B2D0-... | 1 | 102 | 2024-01-15 |

---

## Wiring / Power

The ESP32 runs entirely from USB power:

```
[USB Wall Adapter 5V] ──── [USB Cable] ──── [ESP32 USB Port]
```

- Mount the ESP32 near the front of the classroom (e.g., attached to the projector mount or whiteboard rail) using double-sided tape or a small 3D-printed bracket.
- Keep it away from metal surfaces that can attenuate the BLE signal.
- A standard phone charger (≥500mA) is sufficient.

---

## Signal Power Calibration

The default TX power (`ESP_PWR_LVL_N12`, −12 dBm) is a safe starting point. After flashing, you **must** calibrate each room to confirm the signal does not leak into adjacent spaces.

### Equipment Needed

- A smartphone running a BLE scanner app (e.g., **nRF Connect** for Android/iOS)
- A second person to stand in the hallway
- Notepad or spreadsheet to record RSSI values

### Step-by-Step Calibration Procedure

1. **Flash the firmware** and power the ESP32.
2. Open nRF Connect on your phone and scan for the beacon UUID.
3. **Measure RSSI at 1 meter** (directly in front of the beacon). Record the value and set `CALIBRATED_RSSI_AT_1M` to that reading.
4. **Walk to the farthest desk** in the room. Record the RSSI.
5. **Step into the hallway** (just outside the door). Record the RSSI.
6. **Move 3 meters down the hallway**. Record the RSSI.

### RSSI Measurement Table

| Position | Expected RSSI | Pass Condition |
|----------|--------------|----------------|
| 1 m from beacon | −55 to −65 dBm | Beacon visible and strong |
| Farthest desk in room | −60 to −70 dBm | Must be ≥ −70 dBm |
| Just outside door (hallway) | −75 to −85 dBm | Must be < −75 dBm |
| 3 m down hallway | < −85 dBm or not visible | **Must not be detectable** |

### Pass/Fail Criteria

- ✅ **PASS**: In-room signal is ≥ −70 dBm and hallway signal is < −75 dBm (or undetectable).
- ❌ **FAIL**: The beacon reads ≥ −70 dBm from outside the doorway → reduce TX power.

### Reducing TX Power (If Signal Bleeds Through)

Edit the `TX_POWER` define and re-flash:

```cpp
// Choose ONE power level based on room size and wall construction:
// #define TX_POWER  ESP_PWR_LVL_N9    //  -9 dBm (stronger, large lecture halls)
#define TX_POWER     ESP_PWR_LVL_N12   // -12 dBm (default, standard classroom)
// #define TX_POWER  ESP_PWR_LVL_N15   // -15 dBm (reduced, thin drywall walls)
// #define TX_POWER  ESP_PWR_LVL_N21   // -21 dBm (minimum power, compact lab rooms)
```

Re-run the calibration procedure after each change.

---

## RSSI Threshold in the Flutter App

The Flutter app checks that the beacon's RSSI satisfies the in-room threshold:

```
Detection Threshold: > -70 dBm
```

Any beacon reading weaker than −70 dBm is treated as outside the physical room, and attendance verification is rejected. Configure this via `AppConstants.minBeaconRssi` in `lib/config/constants.dart`.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Beacon not visible in nRF Connect | Wrong board selected / not flashed | Verify `ESP32 Dev Module` selected; re-flash |
| `TX Power` constant not compiling | Old esp32 board package | Update to ≥ 2.0.0 |
| Signal too strong in hallway | Default power too high | Reduce to `ESP_PWR_LVL_N15` or `ESP_PWR_LVL_N21` |
| Signal too weak at far desk | Obstructions (metal furniture) | Reposition beacon; raise power one level |
| UUID not detected by Flutter app | UUID mismatch | Verify UUID matches `AppConstants.targetBeaconUUID` exactly (case-insensitive) |
