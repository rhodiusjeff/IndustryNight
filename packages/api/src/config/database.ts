import { Pool } from 'pg';
import { config } from './env';

// SSL: required in dev/prod (defense in depth), disabled in test (testcontainers has no SSL)
const sslConfig = config.nodeEnv === 'test' ? false : { rejectUnauthorized: false };

const pool = new Pool(
  config.database.url
    ? { connectionString: config.database.url, ssl: sslConfig }
    : {
        host: config.database.host,
        port: config.database.port,
        database: config.database.name,
        user: config.database.user,
        password: config.database.password,
        ssl: sslConfig,
      }
);

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

export async function query<T>(text: string, params?: unknown[]): Promise<T[]> {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result.rows;
  } finally {
    client.release();
  }
}

export async function queryOne<T>(text: string, params?: unknown[]): Promise<T | null> {
  const rows = await query<T>(text, params);
  return rows[0] || null;
}

export async function transaction<T>(
  callback: (client: { query: typeof query }) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback({
      query: async <R>(text: string, params?: unknown[]): Promise<R[]> => {
        const result = await client.query(text, params);
        return result.rows;
      },
    });
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export default pool;
