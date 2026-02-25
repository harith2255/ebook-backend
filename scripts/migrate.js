// scripts/migrate.js — Run once to set up the DB for custom auth
import "dotenv/config";
import pg from "pg";
import bcrypt from "bcrypt";

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes("railway")
    ? { rejectUnauthorized: false }
    : false,
});

const TEMP_PASSWORD = "changeme123";

async function migrate() {
  console.log("🚀 Running migration...\n");

  // 1️⃣ Add new columns
  console.log("1️⃣ Adding columns...");
  await pool.query(`
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS must_reset_password BOOLEAN DEFAULT false;
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_token TEXT;
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMPTZ;
  `);
  console.log("   ✅ Columns added\n");

  // 2️⃣ Hash the temp password
  console.log("2️⃣ Hashing temporary password...");
  const hash = await bcrypt.hash(TEMP_PASSWORD, 12);
  console.log(`   ✅ Temp password: "${TEMP_PASSWORD}"\n`);

  // 3️⃣ Set temp password for existing users who don't have one
  const result = await pool.query(
    `UPDATE profiles 
     SET password_hash = $1, must_reset_password = true
     WHERE password_hash IS NULL
     RETURNING email`,
    [hash]
  );

  console.log(`3️⃣ Updated ${result.rowCount} user(s) with temporary password:`);
  for (const row of result.rows) {
    console.log(`   • ${row.email}`);
  }

  console.log("\n🎉 Migration complete!");
  console.log(`\n📌 Existing users can log in with password: "${TEMP_PASSWORD}"`);
  console.log("   They will be prompted to change it on first login.\n");

  await pool.end();
  process.exit(0);
}

migrate().catch((err) => {
  console.error("❌ Migration failed:", err.message);
  process.exit(1);
});
