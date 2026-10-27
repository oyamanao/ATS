# Technical Documentation & Specifications (`docs/`)

Comprehensive technical architecture, deployment guides, radio signal calibration models, and security threat analyses for the Cheat-Proof Indoor Attendance System (ATS).

---

## 🔄 Evolution & Changelog (Past State vs. Current State)

| Document / Area | Past State | Current State (Work Done & Improved) |
|---|---|---|
| **System Architecture ([`architecture.md`](architecture.md))** | Initial architectural sketches with preliminary sequence flows. | **Complete HLD & LLD Specification**: Synchronized sequence diagrams for device enrollment and attendance submission; formal cryptographic verification models (RSA-2048 + HMAC-SHA256). |
| **Production Setup ([`setup-guide.md`](setup-guide.md))** | Fragmented deployment notes with unstandardized subnet allocations. | **End-to-End Production Guide**: Campus network topology (`192.168.10.0/24`), router BSSID pinning specs, firewall inbound/outbound rules, PM2 process management, and release APK distribution. |
| **Security Hardening ([`security-hardening.md`](security-hardening.md))** | High-level threat descriptions without deep cryptographic mitigation mappings. | **Comprehensive Threat Matrix**: Exhaustive threat models covering WhatsApp photo forwarding, mock GPS spoofing, BLE relay attacks, Android rooting/hooking, and MITM tampering with defense mappings. |
| **ESP32 Calibration ([`esp32-calibration.md`](esp32-calibration.md))** | Generic radio notes with conflicting RSSI thresholds. | **Rigorous Log-Distance Path Loss Model**: Formal radio propagation formulas ($n = 2.4$, $X_\sigma = 4.2\text{ dB}$), survey protocols, wall attenuation tables, and synchronized `-70 dBm` in-room / `-12 dBm` TX power specifications. |

---

## 📚 Document Index

| Guide | Description | Target Audience |
|---|---|---|
| [**Architecture (HLD / LLD)**](architecture.md) | High-Level & Low-Level Design, multi-tier Defense-in-Depth gauntlet, data models, and verification sequences. | System Architects, Engineers |
| [**Production Setup Guide**](setup-guide.md) | Network subnet topology, firewall policies, self-hosted Supabase setup, PM2 backend launch, and mobile APK compilation. | DevOps, SysAdmins |
| [**Security Hardening & Threat Matrix**](security-hardening.md) | Analysis of 12 distinct attack vectors, countermeasures, reverse-engineering defense, and anti-tamper policies. | Security Auditors, Developers |
| [**ESP32 BLE Calibration**](esp32-calibration.md) | Mathematical signal attenuation modeling, field survey procedures, room size TX tuning sheets, and pass/fail criteria. | Hardware Installers |
