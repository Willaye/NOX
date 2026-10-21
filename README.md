<div align="center">

# 🛡️ NOX

### Remote Device Management Platform

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![NestJS](https://img.shields.io/badge/NestJS-E0234E?style=for-the-badge&logo=nestjs&logoColor=white)](https://nestjs.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-010101?style=for-the-badge&logo=socket.io&logoColor=white)](https://socket.io)

**Enterprise-grade mobile device monitoring & management system with real-time tracking, WhatsApp message capture, and remote device control.**

[Features](#-features) · [Architecture](#-architecture) · [Tech Stack](#-tech-stack) · [Screenshots](#-screenshots) · [Setup](#-setup)

</div>

---

## 🔍 What is NOX?

NOX is a self-hosted MDM (Mobile Device Management) platform that enables organizations to monitor and manage employee devices in real time — across any network, any country, 24/7.

**How it works:**
```
Target Phone (Agent App) → Cloud Backend (NestJS) → Admin Phone (Controller App)
        ↓                         ↓                          ↓
  Collects data            Stores & routes            Shows everything
  (GPS, chats,             (PostgreSQL +              (real-time dashboard,
   calls, gallery)          WebSocket)                 alerts, controls)
```

---

## ✨ Features

### 📡 Real-Time Monitoring
| Feature | Description |
|---------|-------------|
| 📍 Live GPS Location | Real-time tracking with city/country names |
| 💬 WhatsApp Messages | Full chat content capture (Accessibility + Notification Listener) |
| 🌐 Browser History | Chrome, Edge, Firefox URL tracking with favicons |
| 📞 Call Logs | Complete call history — incoming, outgoing, missed with duration |
| ✉️ SMS Messages | Full inbox & sent messages |
| 🖼️ Gallery Sync | Photos, videos, screenshots — metadata + binary upload |
| 📊 App Usage | Per-app screen time with daily breakdown |
| 👥 Contacts | Full contact list sync |
| 📋 Clipboard | Copied text monitoring |

### 🔒 Remote Control
| Feature | Description |
|---------|-------------|
| 🔐 Remote Lock | Instantly lock target device |
| 🔓 Remote Unlock | Remove lock remotely |
| 🛡️ Device Admin | Prevent unauthorized app uninstall |
| 🔄 Auto-Start on Boot | Monitoring resumes after every reboot |
| 🔋 Battery Optimized | Foreground service + wake lock for 24/7 operation |

### 🔔 Instant Alerts
| Event | What Happens |
|-------|-------------|
| 🔓 Phone Unlocked | Buzzer sound + visual banner on admin device |
| 📴 Device Offline | Push notification to admin |
| ⚠️ Permission Disabled | Persistent notification on target to re-enable |

### 📲 Zero-Touch Enrollment
```
Admin creates invite → Employee gets email → Opens link on phone →
Downloads APK → App auto-enrolls → Device appears in admin dashboard
```

---

## 🏗️ Architecture

```
┌──────────────────┐       ┌─────────────────────────┐       ┌───────────────────┐
│  TARGET DEVICE    │       │    BACKEND (Cloud)       │       │   ADMIN DEVICE     │
│  Flutter + Kotlin │       │    NestJS + PostgreSQL   │       │   Flutter + Riverpod│
│                   │       │                          │       │                    │
│  • Accessibility  │──REST──▶  • Auth (JWT + Magic)   │◀─REST──│  • Dashboard      │
│  • Notification   │──WS───▶  • Tracking (18 models) │◀──WS───│  • Device Detail  │
│  • Foreground Svc │       │  • WebSocket Gateway     │       │  • WhatsApp View  │
│  • Boot Receiver  │       │  • FCM Push              │       │  • Gallery Viewer  │
│  • Device Admin   │       │  • Enrollment            │       │  • Controls        │
│  • GPS Tracker    │       │  • Cron (offline watch)   │       │  • Alerts + Buzzer │
└──────────────────┘       └─────────────────────────┘       └───────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Admin App** | Flutter 3.x + Riverpod + GoRouter |
| **Agent App** | Flutter 3.x + Kotlin Native Services |
| **Backend** | NestJS 12 + TypeScript |
| **Database** | PostgreSQL 16 + Prisma ORM |
| **Real-time** | Socket.IO 4.x |
| **Auth** | JWT + Magic Link (OTP via email) |
| **Push** | Firebase Cloud Messaging |
| **Deployment** | Docker + Railway |
| **Design System** | Custom `nox_design_system` package |

### Native Android Services (Kotlin)

| Service | Purpose |
|---------|---------|
| `NoxAccessibilityService` | WhatsApp chat content + browser URL extraction |
| `NoxNotificationListenerService` | Message capture from WhatsApp/Telegram/Messenger |
| `TrackingForegroundService` | 24/7 persistent background monitoring |
| `UnlockReceiver` | Screen unlock detection → admin alert |
| `BootReceiver` | Auto-start on reboot + permission check |
| `DeviceAdminReceiver` | Uninstall protection |
| `NativeBridge` | Kotlin ↔ Flutter MethodChannel + EventChannel |

---

## 📂 Project Structure

```
NOX/
├── backend-project/          # NestJS Backend API
│   ├── src/
│   │   ├── admin/            # Dashboard, device CRUD, lock/unlock
│   │   ├── auth/             # JWT + Magic Link authentication
│   │   ├── tracking/         # All monitoring endpoints (18 types)
│   │   ├── gateway/          # Socket.IO real-time gateway
│   │   ├── enroll/           # Email invite → APK → enrollment
│   │   ├── device/           # Device registration + heartbeat
│   │   ├── fcm/              # Firebase push notifications
│   │   └── scheduler/        # Cron: offline watcher
│   └── prisma/schema.prisma  # 18 database models
│
├── nox-flutter-app/          # Agent App (Target Device)
│   ├── lib/services/         # Tracking, location, monitor, gallery, socket
│   └── android/.../kotlin/   # 11 native Kotlin services
│
├── nox/apps/controller_app/  # Admin App (Controller)
│   ├── lib/features/         # Home, Devices, WhatsApp, Gallery, Alerts
│   └── lib/core/             # API client, providers, models, router
│
└── nox/packages/design_system/ # Shared UI components
```

---

## 🗄️ Database Schema

**18 models** including:

`User` · `Device` · `EnrollmentInvite` · `LocationLog` · `AppUsage` · `BrowsingHistory` · `CallLog` · `ScreenTime` · `GalleryItem` · `SmsMessage` · `Contact` · `ClipboardEntry` · `UnlockEvent` · `SocialAppEvent` · `DeviceCommand` · `Notification` · `ActivityLog` · `MagicLink`

---

## 🚀 Setup

### Backend
```bash
cd backend-project
cp .env.example .env           # Configure your environment
docker compose up -d           # Start PostgreSQL
npm install
npx prisma generate && npx prisma db push
npm run seed                   # Create admin user
npm run start:dev              # API at http://localhost:3000/api
```

### Agent App (Target)
```bash
cd nox-flutter-app
# Update lib/config/constants.dart with your backend URL
flutter pub get
flutter build apk --release
```

### Admin App
```bash
cd nox/apps/controller_app
# Update lib/core/network/api_client.dart with your backend URL
flutter pub get
flutter build apk --release
```

---

## 🔐 Security

- **JWT Authentication** with configurable expiry
- **Magic Link Auth** — 6-digit OTP, 15-min expiry, single-use
- **Device JWT** — separate long-lived token for enrolled devices
- **Rate Limiting** — 5 magic links/min, 10 verifications/min
- **Helmet** — HTTP security headers
- **Input Validation** — class-validator on all DTOs
- **bcrypt** — password hashing with auto-salt
- **Prisma** — parameterized queries (SQL injection safe)

---

## 👤 Author

**Willaye Haider**
[Developer Lobby](https://github.com/Willaye)

---

<div align="center">

**NOX** — *See Everything. Control Everything.*

</div>
