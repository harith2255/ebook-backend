import pg from "pg";
import bcrypt from "bcrypt";

const pool = new pg.Pool({
  connectionString: "postgresql://postgres:TEthkeymuyHVtlzHhTEBEtfBeYtMkDXU@turntable.proxy.rlwy.net:38796/railway",
  ssl: { rejectUnauthorized: false },
});

const hash = await bcrypt.hash("changeme123", 12);
console.log("New hash:", hash, "length:", hash.length);

const result = await pool.query(
  `UPDATE profiles SET password_hash = $1 WHERE password_hash IS NOT NULL RETURNING email`,
  [hash]
);

console.log(`\n✅ Updated ${result.rowCount} users:`);
for (const row of result.rows) {
  console.log(`  • ${row.email}`);
}

await pool.end();
