# ESP32 BLE Beacon Calibration & Testing Guide

This guide details the calibration and verification procedures for the ESP32 iBeacon classroom units.

---

## 1. Calibration Objective

The classroom beacon must satisfy two conditions simultaneously:

1. **Inside the Classroom:** The BLE signal must be strong enough ($\text{RSSI} > -70\text{ dBm}$) at **every desk**, including the back row and corners.
2. **Outside the Classroom:** The BLE signal must attenuate to $\text{RSSI} \le -75\text{ dBm}$ (or become undetectable) **1 meter outside the closed classroom door**.

```
   ┌─────────────────────────────────────────────────────────────┐
   │ Classroom                                                   │
   │  [ESP32]                                                    │
   │    │                                                        │
   │    ▼                                                        │
   │   Front Desk: -50 dBm  [PASS]                               │
   │   Middle Desk: -60 dBm [PASS]                               │
   │   Back Row:   -67 dBm  [PASS]                               │
   └───────────────────────────[ Closed Door ]───────────────────┘
                                     │ 1m in Corridor
                                     ▼
                               -78 dBm / No signal [PASS]
```

---

## 2. Tools & Equipment Required

- 1x ESP32 running `classroom_beacon.ino`
- 1x 5V USB power adapter
- 1x Smartphone with a BLE scanner app (e.g. *nRF Connect for Mobile* or the ATS debug build)
- Measuring tape or laser distance meter

---

## 3. Power Level Configuration

In `classroom_beacon.ino`, power is controlled via `NimBLEDevice::setPower(...)`:

| Power Level Macro | Approximate TX Power | Recommended Use Case |
|---|---|---|
| `ESP_PWR_LVL_N21` | **-21 dBm** | Small seminar room or thin glass partition walls (minimum power) |
| `ESP_PWR_LVL_N15` | **-15 dBm** | Medium classroom with signal leaking into adjacent room |
| `ESP_PWR_LVL_N12` | **-12 dBm** | Standard classroom (10m x 8m, brick/drywall) — **Default** |
| `ESP_PWR_LVL_N9`  | **-9 dBm**  | Large lecture hall (20m+ depth, maximum power) |

---

## 4. Step-by-Step Calibration Procedure

### Phase 1: In-Room Verification
1. Mount the ESP32 near the teacher's podium or whiteboard at roughly 2 meters height.
2. Power on the ESP32.
3. Open the BLE scanner app on the test phone and filter by your classroom's configured UUID (e.g., `B9407F30-F5F8-466E-AFF9-25556B57FE6D` or your programmed UUID).
4. Walk to the **furthest corner desk** in the classroom:
   - Observe RSSI for 30 seconds.
   - **Target:** Median RSSI must be **between -60 dBm and -68 dBm**.
   - If RSSI drops below -70 dBm, increase board power to `ESP_PWR_LVL_N9` or relocate the beacon to the room center.

### Phase 2: Corridor Bleed Verification
1. Close all classroom doors and windows.
2. Step **1 meter into the hallway/corridor** directly outside the door.
3. Observe RSSI on the scanner:
   - **Target:** Signal must be $\le -75\text{ dBm}$ or undetectable.
   - **Failure:** If RSSI reads $\ge -70\text{ dBm}$, signal is penetrating the door/walls.
4. **Correction for signal bleed:**
   - Open `classroom_beacon.ino`
   - Change `TX_POWER` to `ESP_PWR_LVL_N15` or `ESP_PWR_LVL_N21`
   - Re-flash the ESP32 and repeat Phase 1 & 2.

---

## 5. Calibration Log Sheet Template

Record calibration results for every room before semester deployment:

| Room | Beacon UUID | Configured TX Power | Far Corner Desk RSSI | 1m Outside Door RSSI | Status | Verified By | Date |
|---|---|---|---|---|---|---|---|
| A101 | `B9407F30-...` | `ESP_PWR_LVL_N12` | -65 dBm | -79 dBm | PASS | Dr. Sharma | 2026-10-15 |
| A102 | `C8219E11-...` | `ESP_PWR_LVL_N21` | -68 dBm | Not Detected | PASS | Dr. Sharma | 2026-10-15 |
| Audi 1 | `D332AA01-...` | `ESP_PWR_LVL_N9` | -67 dBm | -76 dBm | PASS | Prof. Verma | 2026-10-16 |

---

## 6. Maintenance & Replacement

- ESP32 units consume under 0.5W of power and can run continuously.
- If an ESP32 fails, replace the board and flash the **exact same UUID and Major/Minor** from the calibration log so mobile clients do not require database updates.
