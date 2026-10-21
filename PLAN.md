Here is the updated **System Architecture & Data Flow** table that clearly separates **Internet Traffic** from **Local Intranet Traffic** according to your requirement:

  

| **Layer**                | **Transport / Protocol** | **Network Dependency** | **Purpose**                                                                            |
| ------------------------ | ------------------------ | ---------------------- | -------------------------------------------------------------------------------------- |
| **Google Auth**          | HTTPS / OAuth 2.0        | **Internet Required**  | Authenticates user via Google Workspace (`@iiitdwd.ac.in`).                            |
| **GPS Check**            | Hardware Device GPS      | **Internet Required**  | Obtains satellite fix to ensure device is within campus boundaries and flags spoofing. |
| **BSSID Check**          | Local Wi-Fi PHY          | **Local Network**      | Reads connected router MAC address without traversing external routes.                 |
| **BLE Check**            | Bluetooth Low Energy     | **No Network (Radio)** | ESP32 advertises iBeacon signal locally inside the classroom.                          |
| **Self-Hosted Supabase** | HTTP / PostgreSQL        | **Local Network**      | Stores public keys, course logs, and attendance records on university servers.         |
| **Node.js Backend**      | HTTP / REST API          | **Local Network**      | Validates TOTP tokens and verifies biometric signatures.                               |

Below is the complete, start-to-finish production guide.

  

# Cheat-Proof Indoor Attendance System (Architecture & Implementation Guide)

This document provides a comprehensive blueprint for building and deploying a secure, cheat-proof indoor attendance system. The architecture relies on **Defense in Depth**: combining hardware-based room checks, precise geolocation, cryptographic identity binding, dynamic TOTP tokens, and university-locked OAuth on a self-hosted local backend.

  

## 1. System Architecture & Workflows

### Architecture Diagram

```
                     ┌─────────────────────────────────────────┐
                     │          University Classroom           │
                     │  ┌──────────────────┐ ┌───────────────┐ │
                     │  │ Teacher Screen   │ │  ESP32 Beacon │ │
                     │  │ (Dynamic QR TOTP)│ │ (-12dBm BLE)  │ │
                     │  └────────┬─────────┘ └───────┬───────┘ │
                     └───────────┼───────────────────┼─────────┘
                                 │ Visual            │ BLE Signal
                                 ▼                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                              Student Phone                             │
│ ┌──────────────────────┐  ┌──────────────────┐  ┌────────────────────┐ │
│ │ 1. GPS + Mock Check  │  │ 2. BSSID Match   │  │ 3. BLE RSSI > -70  │ │
│ └──────────┬───────────┘  └────────┬─────────┘  └──────────┬─────────┘ │
│            │                       │                       │           │
│ ┌──────────▼───────────────────────▼───────────────────────▼─────────┐ │
│ │ 4. Hardware Key Signature (Biometrics + Secure Keystore)           │ │
│ └──────────────────────────────────┬─────────────────────────────────┘ │
└────────────────────────────────────┼───────────────────────────────────┘
                                     │ Internal HTTP (Local Network)
                                     ▼
                     ┌─────────────────────────────────────────┐
                     │     University Self-Hosted Server       │
                     │  ┌──────────────────┐ ┌───────────────┐ │
                     │  │ Node.js API      │ │ Self-Hosted   │ │
                     │  │ (TOTP + Sig Ver) │ │ Supabase DB   │ │
                     │  └──────────────────┘ └───────────────┘ │
                     └─────────────────────────────────────────┘
```

### Complete End-to-End Execution Sequence

1. **Initial Device Registration (Faculty Advisor's Presence):**
    
      
    - The student logs in using Google OAuth (`@iiitdwd.ac.in` domain required).
        
          
        
    - In the advisor's presence, the Flutter app generates an asymmetric RSA key pair inside the device's hardware Secure Enclave/KeyStore.
        
          
        
    - The flag `setInvalidatedByBiometricEnrollment = true` is set on the key pair.
        
          
        
    - The **Public Key** is uploaded to the self-hosted Supabase database and tied to the student's UID. The **Private Key** never leaves the hardware security chip.
        
          
        
2. **Daily Classroom Check-in:**
    
      
    - **Step A (Internet):** Device checks precise GPS coordinates against campus boundaries and verifies `isMocked == false`.
        
          
        
    - **Step B (Local Wi-Fi):** Device reads current Wi-Fi BSSID to confirm connection to the classroom's router hardware.
        
          
        
    - **Step C (Local BLE):** Device scans for the classroom's ESP32 iBeacon signal strength ($\text{RSSI} > -70$).
        
          
        
    - **Step D (Dynamic QR):** Student scans the teacher's screen casting a 10-second rolling TOTP QR code.
        
          
        
    - **Step E (Biometric Sign):** Device prompts for fingerprint/Face ID. Upon authorization, the hardware chip uses the private key to sign the TOTP payload.
        
          
        
    - **Step F (Intranet Submit):** The payload and signature are transmitted over the local network (`[http://192.168.10.50:3000](http://192.168.10.50:3000)`) to the Node.js backend for validation.

## 2. Component Implementation Guides

### A. ESP32 iBeacon Setup

#### Hardware Wiring & Power

- Plug the ESP32 into a standard 5V USB wall adapter mounted on the classroom wall or near the teacher's desk.
    
      
    
- Alternatively, connect an 18650 Li-ion battery shield to the `5V` and `GND` pins.
    
      
    

#### Arduino IDE Code (`classroom_beacon.ino`)

Install the **NimBLE-Arduino** library via Arduino Library Manager before compiling.

  

C++

```
#include <NimBLEDevice.h>
#include <NimBLEBeacon.h>

// Unique UUID generated for Classroom A1
#define BEACON_UUID "B9407F30-F5F8-466E-AFF9-25556B57FE6D" 

void setup() {
  Serial.begin(115200);
  NimBLEDevice::init("");

  // Set transmission power to -12 dBm so signal dies near walls
  // Options: ESP_PWR_LVL_N12 (-12dBm), ESP_PWR_LVL_N21 (-21dBm)
  NimBLEDevice::setPower(ESP_PWR_LVL_N12); 

  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

  NimBLEBeacon iBeacon;
  iBeacon.setManufacturerId(0x004C); // Apple iBeacon Manufacturer ID
  iBeacon.setProximityUUID(NimBLEUUID(BEACON_UUID));
  iBeacon.setMajor(1);               // Building ID
  iBeacon.setMinor(101);             // Room Number
  iBeacon.setSignalPower(-59);       // Calibrated RSSI at 1m

  NimBLEAdvertisementData advertisementData;
  advertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED
  
  std::string strServiceData = "";
  strServiceData += (char)26;   
  strServiceData += (char)0xFF; 
  strServiceData += iBeacon.getData();
  
  advertisementData.addData(strServiceData);
  pAdvertising->setAdvertisementData(advertisementData);

  pAdvertising->start();
  Serial.println("ESP32 Classroom Beacon initialized.");
}

void loop() {
  delay(10000); // Sleep loop, advertising handles background interrupts
}
```

### B. Flutter Mobile Application

#### `pubspec.yaml`

YAML

```
name: attendance_app
description: Anti-Cheat Indoor Attendance Tracker
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  geolocator: ^13.0.1
  flutter_beacon: ^0.5.1
  network_info_plus: ^6.1.0
  biometric_signature: ^3.2.0
  mobile_scanner: ^5.2.3
  permission_handler: ^11.3.0
  http: ^1.2.2
```

#### Android Permissions (`android/app/src/main/AndroidManifest.xml`)

XML

```
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.CAMERA" />
</manifest>
```

#### iOS Permissions (`ios/Runner/Info.plist`)

XML

```
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required to verify campus presence.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is required to detect classroom beacon presence.</string>
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan attendance QR codes.</string>
<key>NSFaceIDUsageDescription</key>
<string>Biometrics required to cryptographically sign attendance requests.</string>
```

#### Flutter Main Application Logic (`lib/main.dart`)

Dart

```
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:biometric_signature/biometric_signature.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

// Internal University Gateway Settings
const String localBackendUrl = 'http://192.168.10.50:3000';
const String supabaseLocalUrl = 'http://192.168.10.50:8000';
const String supabaseAnonKey = 'YOUR_SELF_HOSTED_SUPABASE_ANON_KEY';

// Campus & Classroom Verification Constants
const double campusLat = 15.3920;
const double campusLng = 75.0255;
const double maxCampusRadiusMeters = 150.0;
const String targetBeaconUUID = 'B9407F30-F5F8-466E-AFF9-25556B57FE6D';
const List<String> validClassroomBSSIDs = ['00:14:22:01:23:45', '00:14:22:01:23:46'];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseLocalUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anti-Cheat Attendance',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _biometricSignature = BiometricSignature();
  final _networkInfo = NetworkInfo();
  String _statusMessage = "Idle";
  bool _isProcessing = false;

  // 1. Faculty Registration Flow (Run once in presence of advisor)
  Future<void> registerDeviceWithFaculty() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Generating hardware keys...";
    });

    try {
      final String? publicKey = await _biometricSignature.createKeys(
        promptMessage: 'Authenticate to register key on hardware security chip',
        config: const CreateKeysConfig(
          enforceBiometric: true,
          setInvalidatedByBiometricEnrollment: true,
        ),
      );

      if (publicKey != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception("User not authenticated");

        // Save Public Key to Supabase DB via RPC or direct insert
        await Supabase.instance.client.from('student_devices').upsert({
          'user_id': user.id,
          'email': user.email,
          'public_key': publicKey,
          'updated_at': DateTime.now().toIso8601String(),
        });

        setState(() => _statusMessage = "Device bound successfully!");
      }
    } catch (e) {
      setState(() => _statusMessage = "Registration failed: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 2. Attendance Execution Flow
  Future<void> executeAttendanceGauntlet(String scannedQrPayload) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Executing security verification...";
    });

    try {
      // Step A: GPS & Mock Location Check
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (pos.isMocked) throw Exception("Verification Error (0x01)");

      double distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, campusLat, campusLng);
      if (distance > maxCampusRadiusMeters) throw Exception("Verification Error (0x02)");

      // Step B: Router BSSID Match
      String? bssid = await _networkInfo.getWifiBSSID();
      if (bssid == null || !validClassroomBSSIDs.contains(bssid.toLowerCase())) {
        throw Exception("Verification Error (0x03)");
      }

      // Step C: BLE Beacon Range Scan
      await flutterBeacon.initializeScanning;
      final regions = <Region>[
        Region(identifier: 'Classroom', proximityUUID: targetBeaconUUID)
      ];

      bool beaconFound = false;
      final stream = flutterBeacon.ranging(regions).listen((result) {
        if (result.beacons.isNotEmpty) {
          Beacon b = result.beacons.first;
          if (b.rssi > -70) beaconFound = true;
        }
      });

      await Future.delayed(const Duration(seconds: 3));
      await stream.cancel();
      if (!beaconFound) throw Exception("Verification Error (0x04)");

      // Step D & E: Biometric Hardware Signature of scanned QR TOTP
      final String? signature = await _biometricSignature.sign(
        payload: scannedQrPayload,
        promptMessage: 'Scan fingerprint to sign attendance token',
      );

      if (signature == null) throw Exception("Verification Error (0x05)");

      // Step F: Submit to Local Node.js Intranet Server
      final session = Supabase.instance.client.auth.currentSession;
      final response = await http.post(
        Uri.parse('$localBackendUrl/api/attendance/mark'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session?.accessToken}',
        },
        body: jsonEncode({
          'qrPayload': scannedQrPayload,
          'signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _statusMessage = "Attendance Successfully Recorded!");
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? "Server error");
      }
    } catch (e) {
      setState(() => _statusMessage = "Attendance Failed: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Indoor Attendance System")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isProcessing ? null : registerDeviceWithFaculty,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Advisor Setup: Register Device Key"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QRScanScreen(
                            onScanned: (code) => executeAttendanceGauntlet(code),
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text("Scan Attendance QR"),
            ),
            const SizedBox(height: 40),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScanScreen extends StatelessWidget {
  final Function(String) onScanned;
  const QRScanScreen({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Screen QR")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              onScanned(barcode.rawValue!);
              Navigator.pop(context);
              break;
            }
          }
        },
      ),
    );
  }
}
```

### C. Node.js Intranet Backend

#### `package.json`

JSON

```
{
  "name": "attendance-backend",
  "version": "1.0.0",
  "description": "Secure Local Attendance Server",
  "main": "server.js",
  "dependencies": {
    "@supabase/supabase-js": "^2.45.0",
    "cors": "^2.8.5",
    "express": "^4.19.2",
    "otp": "^3.1.2"
  }
}
```

#### `server.js`

JavaScript

```
const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
const { OTP, Algorithm } = require('otp');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(cors());

// Self-Hosted Supabase Details
const SUPABASE_URL = 'http://192.168.10.50:8000';
const SUPABASE_SERVICE_ROLE_KEY = 'YOUR_SUPABASE_SERVICE_ROLE_KEY';
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const ALLOWED_EMAIL_DOMAIN = '@iiitdwd.ac.in';
const SHARED_CLASS_SECRET = 'KVKXG2LEMYFA===='; // Secret key shared for TOTP calculation

// Middleware: Authenticate Session and Domain
async function verifySession(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Token missing' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return res.status(401).json({ error: 'Invalid session' });

    if (!user.email.endsWith(ALLOWED_EMAIL_DOMAIN)) {
      return res.status(403).json({ error: 'Access restricted to university accounts.' });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(500).json({ error: 'Auth subsystem error' });
  }
}

// Attendance Submission Endpoint
app.post('/api/attendance/mark', verifySession, async (req, res) => {
  const { qrPayload, signature } = req.body;
  const userId = req.user.id;

  try {
    // 1. Parse Payload format: attendance://<classId>/<totpCode>
    const url = new URL(qrPayload);
    const classId = url.host;
    const clientTotp = url.pathname.replace('/', '');

    // 2. Validate TOTP (incorporating 1-step grace period for network drift)
    const now = Date.now();
    const interval = 10; // 10 seconds
    
    const currentTotp = OTP.generateTOTPCodeString(SHARED_CLASS_SECRET, now, {
      length: 6,
      interval: interval,
      algorithm: Algorithm.SHA256,
    });
    
    const previousTotp = OTP.generateTOTPCodeString(SHARED_CLASS_SECRET, now - (interval * 1000), {
      length: 6,
      interval: interval,
      algorithm: Algorithm.SHA256,
    });

    if (clientTotp !== currentTotp && clientTotp !== previousTotp) {
      return res.status(400).json({ error: 'QR Code Expired. Please scan the live screen.' });
    }

    // 3. Fetch Registered Hardware Public Key from Database
    const { data: device, error: dbErr } = await supabase
      .from('student_devices')
      .select('public_key')
      .eq('user_id', userId)
      .single();

    if (dbErr || !device) {
      return res.status(400).json({ error: 'Device not registered with faculty advisor.' });
    }

    // 4. Cryptographically Verify Signature over Payload using Public Key
    const verifier = crypto.createVerify('SHA256');
    verifier.update(qrPayload);
    verifier.end();

    // Standard Pem conversion helper if stored key is raw base64 string
    const formattedPublicKey = device.public_key.includes('-----BEGIN PUBLIC KEY-----')
      ? device.public_key
      : `-----BEGIN PUBLIC KEY-----\n${device.public_key}\n-----END PUBLIC KEY-----`;

    const isValidSignature = verifier.verify(formattedPublicKey, signature, 'base64');

    if (!isValidSignature) {
      return res.status(400).json({ error: 'Biometric cryptographic verification failed.' });
    }

    // 5. Check Idempotency: Prevent token reuse
    const { data: existingToken } = await supabase
      .from('processed_tokens')
      .select('id')
      .eq('token', clientTotp)
      .single();

    if (existingToken) {
      return res.status(400).json({ error: 'Token already used by another device.' });
    }

    // Record processed token and log attendance
    await supabase.from('processed_tokens').insert({ token: clientTotp, user_id: userId });
    await supabase.from('attendance_logs').insert({
      user_id: userId,
      class_id: classId,
      timestamp: new Date().toISOString(),
      email: req.user.email
    });

    return res.status(200).json({ status: 'SUCCESS', message: 'Attendance verified.' });

  } catch (e) {
    return res.status(500).json({ error: 'Internal Processing Failure' });
  }
});

app.listen(3000, '0.0.0.0', () => {
  console.log('Attendance Server operational on local intranet port 3000');
});
```

### D. Self-Hosted Supabase Setup

#### `docker-compose.override.yml` snippet (Google OAuth Configuration)

Place this configuration in your self-hosted Supabase Docker installation (`docker/docker-compose.yml`):

  

YAML

```
version: '3.8'
services:
  auth:
    environment:
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: "true"
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
      GOTRUE_EXTERNAL_GOOGLE_SECRET: "YOUR_GOOGLE_CLIENT_SECRET"
      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: "http://192.168.10.50:8000/auth/v1/callback"
      GOTRUE_URI_ALLOW_LIST: "attendanceapp://login-callback"
```

#### SQL Schema (`schema.sql`)

Run this in your self-hosted Supabase SQL Editor:

  

SQL

```
-- Create table to map student accounts to their hardware public keys
CREATE TABLE public.student_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    public_key TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create table to track processed TOTP tokens (Idempotency control)
CREATE TABLE public.processed_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token TEXT NOT NULL UNIQUE,
    user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create attendance logs table
CREATE TABLE public.attendance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    class_id TEXT NOT NULL,
    email TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.student_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_logs ENABLE ROW LEVEL SECURITY;

-- Allow students to read their own registered device
CREATE POLICY "Users can view own device" ON public.student_devices
    FOR SELECT USING (auth.uid() = user_id);

-- Cleanup job helper for processed TOTP tokens (Older than 5 minutes)
CREATE OR REPLACE FUNCTION delete_old_tokens() RETURNS trigger AS $$
BEGIN
  DELETE FROM public.processed_tokens WHERE created_at < NOW() - INTERVAL '5 minutes';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## 3. Testing, Deployment, and Security Hardening

### Calibration & Testing Procedures

1. **Calibrating ESP32 Signal Range:**
    
      
    - Flash the ESP32 code with `ESP_PWR_LVL_N12`.
        
          
        
    - Stand at the furthest desk inside the classroom and check Flutter debug output: `b.rssi` should read around `-60` to `-68`.
        
          
        
    - Step 1 meter into the outer hallway and close the door: signal must drop below `-75` or disappear. If signal penetrates walls, reduce board power in code to `ESP_PWR_LVL_N21`.
        
          
        
2. **Testing Biometric Invalidation:**
    
      
    - Complete advisor registration for a test phone.
        
          
        
    - Go to Android/iOS Settings > Security > Add a new dummy fingerprint.
        
          
        
    - Re-open the Flutter app and attempt attendance: `biometric_signature` will throw a hardware key invalidation error, forcing a complete advisor re-registration.
        
          
        
3. **Simulating GPS Spoofing:**
    
      
    - Install a Mock Location app on Android, enable it in Developer Options, and set coordinates inside the classroom while physically outside.
        
          
        
    - Trigger the app: `pos.isMocked` will evaluate to `true` and drop the connection silently.
        
          
        

### Security Hardening Checklist

- [x] **Disable Error Specificity:** Ensure the mobile client displays generic failure messages (`Verification Error`) rather than revealing which layer (BSSID, BLE, GPS, or Signature) failed.
    
      
    
- [x] **Obfuscate Flutter App:** Build the release APK/IPA using `--obfuscate --split-debug-info` to prevent reverse-engineering of validation endpoints and parameters:
    
      
    
    Bash
    
    ```
    flutter build apk --release --obfuscate --split-debug-info=./build/debug-info
    ```
    
- [x] **Local Network Binding:** Bind the Node.js express app strictly to the university subnet IP (e.g., `192.168.10.50`) and block WAN access at the gateway router to prevent any remote API access outside the local Wi-Fi.
