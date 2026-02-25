// utils/db.js — PostgreSQL connection pool for Railway
import pg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes("railway")
    ? { rejectUnauthorized: false }
    : false,
});

// Test connection on startup
pool.query("SELECT NOW()")
  .then(() => console.log("✅ PostgreSQL connected"))
  .catch((err) => console.error("❌ PostgreSQL connection error:", err.message));

/**
 * Helper: run a parameterized query
 * @param {string} text  SQL string with $1, $2 … placeholders
 * @param {any[]}  params  values for the placeholders
 */
export async function query(text, params) {
  return pool.query(text, params);
}

export default pool;
