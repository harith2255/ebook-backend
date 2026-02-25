import 'dotenv/config';
import pool from '../utils/db.js';

// ✅ Keep ONLY these emails
const ALLOWED_EMAILS = [
  "superadmin@gmail.com",
  "harith@gmail.com",
  "alan@gmail.com",
  "amal@gmail.com",
  "jarardh@gmail.com"
];

(async () => {
  console.log("⚠️ Starting FULL AUTH CLEANUP…");

  // 1️⃣ Fetch ALL users from profiles table
  const { rows: users } = await pool.query(`SELECT id, email FROM "profiles"`);

  console.log(`📌 Total Users Found: ${users.length}`);

  // 2️⃣ Filter users NOT in ALLOWED_EMAILS
  const usersToDelete = users.filter(
    (u) => !ALLOWED_EMAILS.includes(u.email?.toLowerCase())
  );

  console.log(`🗑 Users to delete: ${usersToDelete.length}`);

  // 3️⃣ Delete them one-by-one
  for (const user of usersToDelete) {
    console.log(`Deleting: ${user.email} (${user.id})`);

    try {
      await pool.query(`DELETE FROM "profiles" WHERE id = $1`, [user.id]);
      console.log(`✔ Deleted: ${user.email}`);
    } catch (err) {
      console.error(`❌ Error deleting ${user.email}:`, err.message);
    }
  }

  console.log("🎉 AUTH CLEANUP FINISHED!");
  process.exit(0);
})();
