# Security Hardening & Threat Mitigation Guide

This document specifies the threat model, mitigation strategies, and hardening standards implemented across the Cheat-Proof Indoor Attendance System.

---

## 1. Threat Matrix & Defense-in-Depth Enforcement

```
Attacker Goal                   Vector                    Countermeasure
─────────────────────────────────────────────────────────────────────────────────────────────
Proxy attendance remotely      Forwarding Google login   Hardware key in Secure Enclave
Simulate classroom presence    Mock Location / GPS Spoof pos.isMocked flag + Wi-Fi BSSID + BLE
Forward QR to remote friend    WhatsApp / Camera photo   10s rolling TOTP lifetime
Hallway / outside attendance   BLE RF penetration        TX power capped at -12 dBm (RSSI < -70)
Token interception & replay    Packet capture (pcap)     processed_tokens idempotency table
Register friend's fingerprint  Biometric tampering       setInvalidatedByBiometricEnrollment = true
Remote brute-force API flood   Internet bot queries      Intranet-only binding & IP rate limit
Reverse engineer app code      APK decompilation         Flutter release obfuscation + symbol strip
```

---

## 2. Generic Error Masking Policy

To prevent attackers from systematically probing which security layer detected their fraud (e.g. knowing if GPS passed but BSSID failed):

- **The mobile client MUST NOT disclose specific failure reasons to the student.**
- The UI exposes a single unified message with an internal diagnostic hex code:
  ```dart
  'Attendance verification failed. Please ensure you are physically '
  'inside the classroom with location, Bluetooth, and Wi-Fi enabled. (Err: 0x03)'
  ```
- **Error Code Reference (Internal Audit Only):**
  - `0x00`: Location service disabled or permission denied
  - `0x01`: Mock location provider detected (`pos.isMocked == true`)
  - `0x02`: Position outside allowed campus geofence radius
  - `0x03`: Connected Wi-Fi BSSID does not match classroom AP allowlist
  - `0x04`: Classroom ESP32 iBeacon not detected or RSSI $\le -70\text{ dBm}$
  - `0x05`: Biometric prompt cancelled or Secure Enclave signature failed
  - `0x06`: Intranet backend rejected the submission (expired TOTP / bad signature)

---

## 3. Reverse-Engineering Protection (Mobile Obfuscation)

Mobile binaries must be compiled with name mangling and symbol separation to eliminate readable string constants:

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=./build/debug-info
```

For iOS:
```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=./build/debug-info
```

The resulting `./build/debug-info` directory must be archived securely by system administrators to symbolicate genuine crash reports.

---

## 4. Hardware Enclave & Biometric Pinning

The key pair generated during advisor registration is protected by the operating system kernel:

1. **Android KeyStore:**
   - Generated with `KeyProperties.PURPOSE_SIGN` and `KeyProperties.DIGEST_SHA256`.
   - `setUserAuthenticationRequired(true)`: Every single signature invocation triggers biometric challenge.
   - `setInvalidatedByBiometricEnrollment(true)`: Registering any new fingerprint or face model immediately destroys the cryptographic key.

2. **Apple Secure Enclave:**
   - Stored with `kSecAccessControlBiometryAny` and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
   - Key remains in isolated coprocessor silicon; no root exploit or jailbreak can extract the raw private key.

---

## 5. Network Perimeter Isolation

The Node.js backend must never be exposed to public WAN interfaces:

- **Subnet Binding:** Bind strictly to the university internal IP:
  ```env
  HOST=192.168.10.50
  PORT=3000
  ```
- **Firewall Rules:** Block incoming traffic on port 3000 from all external interfaces:
  ```bash
  sudo ufw default deny incoming
  sudo ufw allow from 192.168.10.0/24 to any port 3000 proto tcp
  sudo ufw enable
  ```
- **Cleartext HTTP Restriction:** Cleartext HTTP is permitted *only* for the internal server IP (`192.168.10.50`) via `network_security_config.xml`. All internet traffic (Google OAuth) is locked to TLS 1.3.

---

## 6. Token Idempotency & Lifecycle

- Dynamic QR codes are generated with **HMAC-SHA256** and a **10-second period**.
- The backend accepts the current period and at most 1 previous period ($\pm 10\text{s}$) to allow for transmission jitter.
- The `processed_tokens` table enforces a `UNIQUE` constraint on the 6-digit TOTP code.
- An automated PostgreSQL trigger purges expired tokens older than 5 minutes to maintain database performance:
  ```sql
  CREATE OR REPLACE FUNCTION delete_expired_tokens()
  RETURNS TRIGGER AS $$
  BEGIN
      DELETE FROM public.processed_tokens WHERE created_at < NOW() - INTERVAL '5 minutes';
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
  ```
