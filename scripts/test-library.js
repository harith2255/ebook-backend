import pg from "pg";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";

dotenv.config();

const pool = new pg.Pool({
  connectionString: "postgresql://postgres:TEthkeymuyHVtlzHhTEBEtfBeYtMkDXU@turntable.proxy.rlwy.net:38796/railway",
  ssl: { rejectUnauthorized: false },
});

async function run() {
  try {
    const { rows } = await pool.query("SELECT * FROM profiles LIMIT 1");
    if (rows.length === 0) {
      console.log("No users found.");
      return;
    }
    const user = rows[0];
    
    // 2. Generate token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET || "change-me-in-production"
    );

    const check = async (name, path) => {
      console.log(`\n--- Testing ${name} (${path}) ---`);
      const res = await fetch(`http://localhost:5000${path}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        console.log(`✅ OK (${res.status})`);
      } else {
        console.log(`❌ Failed: ${res.status}`);
        const text = await res.text();
        console.log(text);
      }
    };

    await check("Library", "/api/library");
    await check("Content Books", "/api/content?type=books");
    await check("Ongoing Mock Tests", "/api/mock-tests/ongoing");
    await check("Completed Mock Tests", "/api/mock-tests/completed");
    await check("Mock Tests", "/api/mock-tests");

  } finally {
    pool.end();
  }
}

run();
