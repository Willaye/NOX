# Nox — Remote Device Monitoring Backend

Backend API for the Nox remote device monitoring system. Built with NestJS, PostgreSQL, and Prisma.

## What is Nox?

Nox is a remote device monitoring and management platform — similar to AirDroid but without the same-network WiFi restriction. Monitor and manage devices from anywhere, over any network.

## Tech Stack

- **NestJS** — TypeScript API framework
- **PostgreSQL 16** — database (via Docker)
- **Prisma** — ORM and database migrations
- **JWT** — authentication with bcrypt password hashing
- **Vitest** — test runner
- **OxLint** — linter

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/signup` | Create account |
| POST | `/api/auth/login` | Login, get JWT token |
| GET | `/api/auth/profile` | Get user profile + devices |

### Devices
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/devices` | Register a new device |
| POST | `/api/devices/pair` | Pair device with code |
| GET | `/api/devices` | List your devices |
| GET | `/api/devices/:id` | Device detail + recent logs |
| PUT | `/api/devices/:id` | Update device name |
| DELETE | `/api/devices/:id` | Remove a device |
| POST | `/api/devices/:id/heartbeat` | Device agent heartbeat |

### Activity Logs
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/activity-logs` | Log device activity |
| POST | `/api/activity-logs/batch` | Batch log activities |
| GET | `/api/activity-logs/device/:id` | Query activity by device |
| GET | `/api/activity-logs/device/:id/stats` | Activity stats |

### Location Logs
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/location-logs` | Log device location |
| POST | `/api/location-logs/batch` | Batch log locations |
| GET | `/api/location-logs/device/:id` | Location history |
| GET | `/api/location-logs/device/:id/latest` | Latest location |

## Setup

### Prerequisites
- Node.js 20+
- Docker (for PostgreSQL)

### Install & Run

```bash
# Install dependencies
npm install

# Start PostgreSQL
docker compose up -d

# Push database schema
npx prisma db push

# Start in dev mode
npm run start:dev
```

The API will be running at `http://localhost:3000/api`

### Environment Variables

Create a `.env` file (see `.env` for defaults):

```
DATABASE_URL="postgresql://myuser:12345678@localhost:5433/mydatabase?schema=public"
JWT_SECRET="your-secret-key"
```

## Scripts

```bash
npm run start:dev    # Development with watch mode
npm run build        # Compile TypeScript
npm run start:prod   # Run compiled output
npm run test         # Unit tests
npm run test:e2e     # End-to-end tests
npm run lint         # Lint with OxLint
npm run format       # Format with Prettier
```

## Project Structure

```
src/
├── main.ts                          # App bootstrap
├── app.module.ts                    # Root module
├── app.controller.ts                # Health check endpoint
├── app.service.ts                   # App service
├── auth/                            # Authentication module
│   ├── auth.module.ts
│   ├── auth.service.ts              # Signup, login, profile
│   ├── auth.controller.ts
│   ├── jwt.strategy.ts              # Passport JWT strategy
│   ├── guards/jwt-auth.guard.ts     # Route protection
│   └── dto/                         # Signup & login DTOs
├── device/                          # Device management module
│   ├── device.module.ts
│   ├── device.service.ts            # CRUD, pairing, heartbeat
│   ├── device.controller.ts
│   └── dto/                         # Device DTOs
├── activity-log/                    # Activity logging module
│   ├── activity-log.module.ts
│   ├── activity-log.service.ts
│   ├── activity-log.controller.ts
│   └── dto/
├── location-log/                    # Location tracking module
│   ├── location-log.module.ts
│   ├── location-log.service.ts
│   ├── location-log.controller.ts
│   └── dto/
└── prisma/                          # Database service
    ├── prisma.module.ts
    └── prisma.service.ts
```
