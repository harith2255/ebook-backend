import supabase from "../../utils/supabaseClient.js";

// Users to delete
const DELETE_EMAILS = [
  "test2@gmail.com",
  "carol@example.com",
  "bob@example.com",
];

const RELATED_TABLES = [
  "profiles",
  "subscriptions",
  "book_sales",
  "activity_log",
  "user_notifications",
  "payments_transactions",
  "writing_orders",
  "notes",
  "purchases",
  "mock_test_attempts",
  "jobs_applications"
];

export const cleanSeeder = async (req, res) => {
  try {
    console.log("🧹 Starting Seeder Cleanup...");

    // 1️⃣ Fetch users by email
    const {
      data: users,
      error: fetchErr
    } = await supabase
      .from("profiles")
      .select("id, email")
      .in("email", DELETE_EMAILS);

    if (fetchErr) {
      console.error(fetchErr);
      return res.status(500).json({ error: fetchErr.message });
    }

    if (!users.length) {
      return res.json({ message: "No seeded users found." });
    }

    console.log("Deleting these users:", users);

    for (const user of users) {
      const userId = user.id;

      console.log(`\n🗑 Deleting user: ${user.email} (${userId})`);

      // 2️⃣ DELETE FROM RELATED TABLES
      for (const table of RELATED_TABLES) {
        await supabase.from(table).delete().eq("user_id", userId);
      }

      // profiles table uses "id"
      await supabase.from("profiles").delete().eq("id", userId);

      // 3️⃣ DELETE AUTH USER
      const { error: authErr } = await supabase.auth.admin.deleteUser(userId);
      if (authErr) {
        console.error(`Auth delete error for ${user.email}:`, authErr);
      } else {
        console.log(`✔ Auth deleted: ${user.email}`);
      }
    }

    return res.json({
      message: "Seeder users deleted successfully",
      deleted: users,
    });

  } catch (err) {
    console.error("Cleanup Error:", err);
    return res.status(500).json({
      error: "Server error during seeder cleanup",
    });
  }
};
