import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

// --- Admin client (required for deleting users) ---
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

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

  // 1️⃣ Fetch ALL users from Supabase Auth
  const { data: userList, error } = await supabaseAdmin.auth.admin.listUsers();

  if (error) {
    console.error("❌ Error fetching users:", error);
    return;
  }

  console.log(`📌 Total Auth Users Found: ${userList.users.length}`);

  // 2️⃣ Filter users NOT in ALLOWED_EMAILS
  const usersToDelete = userList.users.filter(
    (u) => !ALLOWED_EMAILS.includes(u.email?.toLowerCase())
  );

  console.log(`🗑 Users to delete: ${usersToDelete.length}`);

  // 3️⃣ Delete them one-by-one
  for (const user of usersToDelete) {
    console.log(`Deleting: ${user.email} (${user.id})`);

    const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(user.id);

    if (delErr) {
      console.error(`❌ Error deleting ${user.email}:`, delErr.message);
    } else {
      console.log(`✔ Deleted: ${user.email}`);
    }
  }

  console.log("🎉 AUTH CLEANUP FINISHED!");
})();
