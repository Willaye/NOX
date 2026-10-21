# NOX — Remote Device Management Platform

> "Your Devices. Closer Than You Think."

NOX is a centralized, authorized multi-device management and remote-support platform. Securely enroll and manage devices from anywhere — different Wi-Fi, different cities, different countries.

## Architecture

```
/nox
├── apps/
│   └── controller_app/          # Flutter controller app (14 screens)
├── backend/                     # NestJS API (14 modules)
│   └── src/
│       ├── auth/                # JWT + refresh tokens + sessions
│       ├── users/               # User CRUD + profiles
│       ├── devices/             # Device management + heartbeat
│       ├── pairing/             # Secure device enrollment
│       ├── sessions/            # Device session tracking
│       ├── files/               # File metadata + S3 signed URLs
│       ├── notifications/       # Notification center
│       ├── messages/            # Device-to-controller messaging
│       ├── audit/               # Tamper-resistant audit logging
│       ├── alerts/              # Security & system alerts
│       ├── admin/               # Admin dashboard + management
│       ├── health/              # Health checks (live/ready)
│       ├── gateway/             # WebSocket real-time gateway
│       ├── prisma/              # Database service
│       └── common/              # Shared DTOs, guards, decorators
├── packages/
│   └── design_system/           # NOX Design System (17 components)
├── database/
│   └── prisma/
│       ├── schema.prisma        # 20+ models with relations
│       └── seed.ts              # Roles, permissions, portals, admin
├── infrastructure/
│   └── docker/
│       ├── docker-compose.yml   # PostgreSQL + Redis + MinIO
│       └── Dockerfile.backend   # Production backend image
└── docs/
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | NestJS, TypeScript, Prisma, PostgreSQL |
| Auth | JWT + Refresh Tokens, bcrypt, RBAC |
| Real-time | WebSocket (Socket.IO) |
| Storage | S3-compatible (MinIO) |
| Frontend | Flutter, Riverpod, GoRouter, Dio |
| Design | Custom NOX Design System |
| Infrastructure | Docker, Docker Compose |

## Quick Start

### Prerequisites
- Node.js 20+
- Docker & Docker Compose
- Flutter SDK 3.10+

### 1. Start Infrastructure
```bash
cd infrastructure/docker
docker compose up -d
```

### 2. Setup Backend
```bash
cd backend
npm install --legacy-peer-deps
npx prisma generate --schema=../database/prisma/schema.prisma
npx prisma db push --schema=../database/prisma/schema.prisma
npx tsx ../database/prisma/seed.ts
npm run start:dev
```

API at http://localhost:3000/api
Swagger at http://localhost:3000/api/docs

### 3. Run Flutter App
```bash
cd apps/controller_app
flutter pub get
flutter run
```

## API Endpoints

### Auth
- `POST /api/auth/signup` — Create account
- `POST /api/auth/login` — Login
- `POST /api/auth/refresh` — Refresh tokens
- `POST /api/auth/logout` — Logout
- `GET /api/auth/profile` — Current user profile
- `GET /api/auth/sessions` — Active sessions

### Devices
- `POST /api/devices` — Register device
- `GET /api/devices` — List devices
- `GET /api/devices/:id` — Device detail
- `PUT /api/devices/:id` — Update device
- `DELETE /api/devices/:id` — Delete device
- `POST /api/devices/:id/heartbeat` — Device heartbeat

### Pairing
- `POST /api/pairing/generate` — Generate pairing code
- `POST /api/pairing/validate` — Validate code
- `POST /api/pairing/complete` — Complete pairing

### Files
- `POST /api/files/upload-url` — Get upload URL
- `POST /api/files/confirm` — Confirm upload
- `GET /api/files/device/:id` — Device files
- `GET /api/files/:id/download` — Download URL
- `DELETE /api/files/:id` — Delete file

### Notifications, Messages, Alerts, Audit, Admin
See Swagger docs at `/api/docs`

## Database Schema

20+ models including:
- User, Organization, Role, Permission, UserRole
- Device, DeviceSession, DevicePermission
- PairingSession, RefreshToken
- File, FileTransfer
- Notification, Message
- RemoteSession, SupportSession
- AuditLog, Alert
- Portal, Workspace

## Security

- JWT access tokens (15m expiry)
- Refresh token rotation (7d expiry)
- Password hashing (bcrypt, 12 rounds)
- RBAC (Super Admin, Admin, Support, Org Admin, User)
- Rate limiting (100 req/min)
- CORS, Helmet, input validation
- Audit logging on all sensitive actions
- Device authorization on every request
- WebSocket JWT authentication

## Environment Variables

See `.env.example` for all required variables.

## Default Admin

After seeding:
- Email: `admin@nox.dev`
- Password: `NoxAdmin@2024`
- Role: SUPER_ADMIN
