# Dev Workflow

## Purpose
This document is the fastest way to bring up the local development stack for:
- `Go` backend
- `Next.js` CMS
- `Flutter` iOS learner app

The workflow is intentionally simple. Use separate terminals and keep each surface easy to restart.

## Recommended Startup Order
1. Start the backend
2. Start the CMS
3. Start the Flutter iOS app

This order makes it easier to verify dependencies:
- CMS depends on the backend API
- Flutter depends on the backend API

## Terminal 1: Backend
From the repo root:

```bash
make dev-backend
```

Expected result:
- backend listens on `http://localhost:8080`
- health endpoint responds at `http://localhost:8080/healthz`

## Terminal 2: CMS
From the repo root:

```bash
make dev-cms
```

Expected result:
- CMS dev server runs at `http://localhost:3000`

Open:
- [CMS](http://localhost:3000)

## Terminal 3: Flutter
From the repo root:

```bash
make dev-ios
```

Expected result:
- Flutter launches the learner app on the iOS simulator or connected device

If Flutter cannot resolve the default iOS target, list devices first:

```bash
make flutter-devices
```

Then run with an explicit device name:

```bash
make dev-ios IOS_DEVICE="iPhone 17 Pro Max"
```

Or with a connected phone:

```bash
make dev-ios IOS_DEVICE="00008110-00182CC20C2B801E"
```

## Quick Health Check
After backend and CMS are up:

```bash
make dev-check
```

This checks:
- backend health on `:8080`
- CMS response on `:3000`

## Recommended Daily Flow
1. `make dev-backend`
2. `make dev-cms`
3. `make dev-ios`
4. `make dev-check`

Use this when resuming work after a pause.

## Stop Workflow

### Stop Backend
```bash
make dev-stop-backend
```

### Stop CMS
```bash
make dev-stop-cms
```

### Stop Both Web Services
```bash
make dev-stop
```

This stops processes by port:
- backend on `:8080`
- CMS on `:3000`

### Stop Flutter
Stop Flutter from the terminal running `make dev-ios`:
- press `q` inside `flutter run`
- or press `Ctrl+C`

## Verification Flow Before Stopping
Run these before ending a meaningful coding session:

```bash
make backend-build
make cms-lint
make cms-build
make flutter-analyze
make flutter-test
```

Or run:

```bash
make verify
```

## Common Issues

### Port Already In Use
If `:8080` or `:3000` is already in use, one of the services may already be running from an earlier session.

In that case:
- reuse the running process if it is healthy
- or stop it with `make dev-stop-backend`, `make dev-stop-cms`, or `make dev-stop` and restart with the `make dev-*` commands above

### Flutter Startup Lock
If Flutter says another command holds the startup lock:
- wait a few seconds
- rerun the command

### Flutter Cannot Find `ios`
If Flutter says no device matches `ios`, that means it needs a concrete simulator name or device id.

Use:

```bash
make flutter-devices
make dev-ios IOS_DEVICE="iPhone 17 Pro Max"
```

### CMS Starts But Page Looks Stale
Restart the CMS dev server:

```bash
make dev-cms
```

### Flutter Talks To Wrong API Host
The app currently assumes the backend is reachable at:
- `http://localhost:8080`

If that changes, update the dev API base in the learner app before continuing.

## Notes
- Keep the current upload contract stable while iterating on the backend internals.
- Do not reintroduce remote font fetching.
- Use `rtk`-prefixed commands directly only when you are not using the root `Makefile`.
