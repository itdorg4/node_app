# Node Application

A simple Node.js HTTP server using only the built-in `http` module (no dependencies).

## Run

```bash
npm start
```

The server listens on port `3000` (override with the `PORT` environment variable).

## Endpoints

| Method | Path      | Description                |
|--------|-----------|----------------------------|
| GET    | `/`       | Returns a hello message    |
| GET    | `/health` | Health check + uptime      |
