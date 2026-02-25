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
    // 1. Get a valid user
    const { rows } = await pool.query("SELECT * FROM profiles LIMIT 1");
    if (rows.length === 0) {
      console.log("No users found.");
      return;
    }
    const user = rows[0];
    
    // 2. Generate a valid token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET || "change-me-in-production"
    );

    console.log(`Testing with user: ${user.email} (${user.id})`);

    // 3. Test Dashboard endpoint
    console.log("\n--- Testing /api/dashboard ---");
    const dashRes = await fetch("http://localhost:5000/api/dashboard", {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    if (dashRes.ok) {
      console.log("✅ Dashboard OK");
    } else {
      console.log(`❌ Dashboard Failed: ${dashRes.status}`);
      const text = await dashRes.text();
      console.log(text);
    }

    // 4. Test Active Subscription endpoint
    console.log("\n--- Testing /api/subscriptions/active ---");
    const subRes = await fetch("http://localhost:5000/api/subscriptions/active", {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    if (subRes.ok) {
      console.log("✅ Subscriptions OK");
    } else {
      console.log(`❌ Subscriptions Failed: ${subRes.status}`);
      const text = await subRes.text();
      console.log(text);
    }
    
  } catch (err) {
    console.error("Test error:", err);
  } finally {
    pool.end();
  }
}

run();
