# MMS Backend Development Setup

## 1. Purpose

This guide starts the local development infrastructure for MMS backend.

Services provided:
- Host MariaDB on `127.0.0.1:3306`
- Redis on `127.0.0.1:6379`

The defaults match [`.env.example`](/home/jaykali/madrasa/backend/.env.example:1).

---

## 2. Start Infrastructure

From the repository root:

Start Redis:

```bash
docker compose up -d
```

If your machine does not have the Docker Compose plugin, use the fallback script:

```bash
bash scripts/dev-infra-up.sh
```

Check status:

```bash
docker compose ps
```

Stop services:

```bash
docker compose down
```

Fallback:

```bash
bash scripts/dev-infra-down.sh
```

Stop services and remove volumes:

```bash
docker compose down -v
```

---

## 3. Prepare Backend Env

Create the backend env file:

```bash
cp backend/.env.example backend/.env
```

Current defaults:
- database name: `mms`
- database user: `mms_user`
- database password: `mms_password`
- database port: `3306`
- redis URL: `redis://127.0.0.1:6379`

---

## 4. Run Wave 1 Migration

From `backend/`:

```bash
npm run prisma:migrate:deploy
```

If you want Prisma to generate the client again:

```bash
npm run prisma:generate
```

---

## 5. Seed First Admin

From `backend/`:

```bash
npm run seed:admin
```

Default seeded values come from `.env`:
- organization: `Demo Madrasa`
- branch: `Main Campus`
- admin email: `admin@example.com`
- admin password: `ChangeMe123!`

Change these values before seeding any shared environment.

---

## 6. Start Backend

From `backend/`:

```bash
npm run dev
```

Health check:

```bash
curl http://127.0.0.1:4000/api/health
```

---

## 7. Recommended First Run Order

1. Start MariaDB host service and confirm `mms` exists on `127.0.0.1:3306`
2. `cp backend/.env.example backend/.env`
3. `docker compose up -d`
4. `cd backend`
5. `npm run prisma:migrate:deploy`
6. `npm run seed:admin`
7. `npm run dev`
