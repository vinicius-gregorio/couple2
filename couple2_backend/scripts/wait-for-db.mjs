/**
 * Block until the Postgres from DATABASE_URL accepts TCP connections.
 * Used by the backend container so it can boot after `supabase start`.
 */
import net from 'node:net';

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL is not set');
  process.exit(1);
}

const url = new URL(databaseUrl);
const host = url.hostname;
const port = Number(url.port || 5432);
const deadline = Date.now() + 90_000;

function tryOnce() {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    const done = (ok) => {
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(2000);
    socket.on('connect', () => done(true));
    socket.on('error', () => done(false));
    socket.on('timeout', () => done(false));
  });
}

while (Date.now() < deadline) {
  if (await tryOnce()) {
    console.log(`database reachable at ${host}:${port}`);
    process.exit(0);
  }
  console.log(`waiting for database at ${host}:${port}...`);
  await new Promise((resolve) => setTimeout(resolve, 2000));
}

console.error(
  `database at ${host}:${port} did not become reachable. Start it with \`supabase start\` from the repo root.`,
);
process.exit(1);
