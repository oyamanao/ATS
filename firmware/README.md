# ESP32 Classroom Beacon Firmware

Classroom presence hardware component for the Cheat-Proof Indoor Attendance System (ATS). Broadcasts tuned Bluetooth Low Energy (BLE) Apple iBeacon signals inside university lecture halls to enforce physical in-room presence verification.

---

## 🔄 Evolution & Changelog (Past State vs. Current State)

| Component / Area | Past State | Current State (Work Done & Improved) |
|---|---|---|
| **BLE Protocol Stack** | Legacy ESP32 Bluedroid stack consumed excessive RAM (~150KB) and flash memory, leading to sporadic heap exhaustion. | **Migrated to `NimBLE-Arduino` (>= 1.4.0)**, reducing memory footprint by >50% and improving connection-less advertising throughput. |
| **RF Power & Wall Bleed** | Full/default TX power (0 to +3 dBm) allowed beacon signals to penetrate concrete walls into hallways and adjacent rooms. | **Tuned TX Power to `-12 dBm` (`ESP_PWR_LVL_N12`)** with calibrated -59 dBm 1m reference RSSI, confining signals strictly to the classroom. |
| **In-Room RSSI Cutoff** | Mobile threshold and beacon calibration figures were inconsistently defined (-88 dBm vs -70 dBm). | **Synchronized Detection Threshold**: Flutter mobile client requires `RSSI > -70 dBm`; signals in hallways attenuate to `< -75 dBm` or become undetectable. |
| **Payload Assembly** | Indirect string-based beacon encoding causing incompatibility across NimBLE versions. | **Standardized 27-byte Raw Memory Assembly** (`0x004C` Apple ID, UUID, Major, Minor, Calibrated RSSI) ensuring cross-version stability. |
| **Task & CPU Scheduling** | Busy-wait `delay()` loops that could trigger FreeRTOS Task Watchdog Timer (TWDT) resets. | **FreeRTOS Low-Power Yield** using `vTaskDelay(portMAX_DELAY)` to eliminate CPU spinning while letting background BLE tasks run unimpeded. |
| **Field Diagnostics** | No hardware visual indicators on boot; required serial monitor to verify operation. | **Boot Diagnostic Double-Blink** on GPIO 2 (onboard LED) to confirm power, initialization, and active advertising to physical installers. |

---

## 📂 Subdirectory Structure

```
firmware/
├── libraries.txt                    # Arduino Board Manager URL and library version definitions
└── classroom_beacon/
    ├── classroom_beacon.ino         # Optimized NimBLE iBeacon transmitter firmware
    └── README.md                    # In-depth flashing, wiring, and RF calibration guide
```

---

## ⚡ Quick Flashing Instructions

1. **Open Arduino IDE 2.x**.
2. **Install Board Core**: Add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json` to Preferences and install `esp32` via Boards Manager.
3. **Install Library**: Install **NimBLE-Arduino** (by h2zero, version $\ge 1.4.0$) via Library Manager.
4. **Configure Sketch**: Open [`classroom_beacon/classroom_beacon.ino`](classroom_beacon/classroom_beacon.ino) and adjust `BEACON_UUID`, `BUILDING_ID`, and `ROOM_NUMBER`.
5. **Flash Board**: Select **ESP32 Dev Module**, choose your COM port, and upload at `921600` baud.
6. **Verify**: The onboard LED will double-blink upon boot, confirming active iBeacon transmission.

See [`classroom_beacon/README.md`](classroom_beacon/README.md) for detailed field calibration procedures.
