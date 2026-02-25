import express from "express";
import supabase from "../../utils/supabaseClient.js";
import bcrypt from "bcrypt";

const router = express.Router();

/* ------------------------------
   Helper Functions
------------------------------ */
const rand = (min, max) =>
  Math.floor(Math.random() * (max - min + 1)) + min;

function randomDate() {
  const now = new Date();
  const past = new Date();
  past.setMonth(now.getMonth() - 6);

  return new Date(
    past.getTime() + Math.random() * (now.getTime() - past.getTime())
  ).toISOString();
}

const sampleBooks = [
  "Advanced Physics", "Machine Learning Essentials",
  "Organic Chemistry Guide", "Data Structures in C++",
  "Irrigation Engineering", "Plant Biology Notes"
];

const categories = [
  "Science", "Engineering", "Agriculture",
  "Computer Science", "Mathematics"
];

/* ------------------------------
   SEED DASHBOARD
------------------------------ */
router.post("/seed-dashboard", async (req, res) => {
  try {
    const names = [
      "Aarav Sharma", "Vihaan Patel", "Riya Nair",
      "Anaya Iyer", "Kabir Reddy", "Dev Singh",
      "Sara Kapoor", "Meera Das", "Karan Jain", "Sneha Bose"
    ];

    const createdUsers = [];

    /* ------------------------------------
       1️⃣ Create 10 test users
    ------------------------------------ */
    for (let i = 0; i < 10; i++) {
      const email = `seed_${Date.now()}_${i}@test.com`;
      const password_hash = await bcrypt.hash("password123", 12);

      const { data: newUser, error } = await supabase
        .from("profiles")
        .insert({
          email,
          password_hash,
          full_name: names[i],
          role: "User",
          account_status: "active",
          created_at: new Date(),
        })
        .select("id")
        .single();

      if (error) continue;

      const userId = newUser.id;

      await supabase.from("profiles").upsert([
        {
          id: userId,
          full_name: names[i],
        }
      ]);

      createdUsers.push(userId);
    }

    /* ------------------------------------
       2️⃣ Seed Books + User Book Progress
    ------------------------------------ */
    for (const userId of createdUsers) {
      for (let i = 0; i < 5; i++) {
        await supabase.from("user_books").insert([
          {
            user_id: userId,
            book_id: rand(1, 5), // match your books table IDs
            status: i % 2 === 0 ? "completed" : "reading",
            progress: rand(10, 90),
            updated_at: randomDate()
          }
        ]);
      }
    }

    /* ------------------------------------
       3️⃣ Seed Test Results
    ------------------------------------ */
    for (const userId of createdUsers) {
      for (let i = 0; i < 3; i++) {
        await supabase.from("test_results").insert([
          {
            user_id: userId,
            score: rand(40, 100),
            completed_at: randomDate()
          }
        ]);
      }
    }

    /* ------------------------------------
       4️⃣ Seed Study Sessions
    ------------------------------------ */
    for (const userId of createdUsers) {
      for (let i = 0; i < 4; i++) {
        await supabase.from("study_sessions").insert([
          {
            user_id: userId,
            duration: rand(1, 5), // hours
            date: randomDate()
          }
        ]);
      }
    }

    /* ------------------------------------
       5️⃣ Seed Active Streaks
    ------------------------------------ */
    for (const userId of createdUsers) {
      await supabase.from("user_streaks").upsert([
        {
          user_id: userId,
          streak_days: rand(1, 15)
        }
      ]);
    }

    /* ------------------------------------
       6️⃣ Seed Upcoming Mock Tests
    ------------------------------------ */
    for (let i = 0; i < 5; i++) {
      await supabase.from("mock_tests").insert([
        {
          title: sampleBooks[rand(0, sampleBooks.length - 1)] + " Test",
          scheduled_date: new Date(Date.now() + rand(1, 10) * 86400000),
          total_questions: rand(20, 50)
        }
      ]);
    }

    /* ------------------------------------
       7️⃣ Seed User Activity Logs
    ------------------------------------ */
    for (const userId of createdUsers) {
      await supabase.from("user_activity").insert([
        {
          user_id: userId,
          action: "purchased book",
          details: sampleBooks[rand(0, sampleBooks.length - 1)],
          type: "purchase",
          created_at: randomDate()
        }
      ]);
    }

    res.json({
      message: "Dashboard seed inserted successfully!",
      users_created: createdUsers.length
    });

  } catch (err) {
    console.error("Seed error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
