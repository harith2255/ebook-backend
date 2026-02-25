import pg from "pg";

const pool = new pg.Pool({
  connectionString: "postgresql://postgres:TEthkeymuyHVtlzHhTEBEtfBeYtMkDXU@turntable.proxy.rlwy.net:38796/railway",
  ssl: { rejectUnauthorized: false },
});

const tables = await pool.query(
  `SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename`
);
console.log(`✅ ${tables.rows.length} tables on Railway:`);
for (const r of tables.rows) console.log(`  • ${r.tablename}`);

// Check profiles data
const profiles = await pool.query(`SELECT count(*) as cnt FROM profiles`);
console.log(`\n👤 Profiles: ${profiles.rows[0].cnt} rows`);

// Check if password_hash column exists
try {
  const cols = await pool.query(`SELECT column_name FROM information_schema.columns WHERE table_name='profiles' AND column_name='password_hash'`);
  console.log(`🔑 password_hash column: ${cols.rows.length > 0 ? 'EXISTS' : 'MISSING'}`);
} catch(e) { console.log('password_hash check error:', e.message); }

await pool.end();
