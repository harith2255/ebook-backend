import express from "express";
import supabase from "../../utils/supabaseClient.js";

const router = express.Router();

/* -----------------------------------------
   CONSTANT DATA
----------------------------------------- */
const indianNames = [
  "Aarav", "Vivaan", "Aditya", "Kabir", "Arjun",
  "Diya", "Anaya", "Isha", "Riya", "Saanvi"
];

const sampleBooks = [
  "Advanced Physics", "Organic Chemistry Guide",
  "Modern Agriculture Handbook", "Data Structures in C++",
  "Soil Science Basics", "Irrigation Engineering",
  "Machine Learning Essentials", "Plant Biology Notes"
];

const categories = [
  "Science", "Engineering", "Agriculture",
  "Computer Science", "Mathematics"
];

const activityTypes = ["subscription", "content", "login", "purchase"];

/* -----------------------------------------
   HELPERS
----------------------------------------- */
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

function getAction(type) {
  switch (type) {
    case "subscription":
      return "activated a subscription";
    case "content":
      return `uploaded a book "${sampleBooks[rand(0, sampleBooks.length - 1)]}"`;
    case "login":
      return "logged in";
    case "purchase":
      return `purchased "${sampleBooks[rand(0, sampleBooks.length - 1)]}"`;
    default:
      return "performed an action";
  }
}

/* -----------------------------------------
   ROUTE: Seed Dashboard
----------------------------------------- */

router.post("/seed-dashboard", async (req, res) => {
  try {
    const names = [
      "Aarav Sharma", "Vihaan Patel", "Riya Nair",
      "Anaya Iyer", "Kabir Reddy", "Dev Singh",
      "Sara Kapoor", "Meera Das", "Karan Jain", "Sneha Bose"
    ];

    const plans = ["Monthly", "Annual", "Student"];

    const createdUsers = [];

    // 1️⃣ Wipe old subscription data only
    await supabase.from("subscriptions").delete().neq("id", "");

    // 2️⃣ Create 10 users & profiles
    for (let i = 0; i < 10; i++) {
      const email = `seed_${Date.now()}_${i}@test.com`;

      const { data: newUser, error } = await supabase.auth.admin.createUser({
        email,
        password: "password123",
        email_confirm: true
      });

      if (error) continue;

      const userId = newUser.user.id;

      await supabase.from("profiles").upsert([
        {
          id: userId,
          full_name: names[i],
          avatar_url: null
        }
      ]);

      createdUsers.push({ userId, name: names[i] });

      // Insert subscription
      await supabase.from("subscriptions").insert([
        {
          user_id: userId,
          plan: plans[rand(0, plans.length - 1)],
          amount: rand(100, 900),
          status: "active",
          start_date: new Date(),
          end_date: new Date(Date.now() + 30 * 86400000)
        }
      ]);
    }

    // 3️⃣ Book sales
    await supabase.from("book_sales").insert(
      Array.from({ length: 15 }).map(() => ({
        price: rand(100, 999),
        book_name: sampleBooks[rand(0, sampleBooks.length - 1)],
        category: categories[rand(0, categories.length - 1)],
        created_at: randomDate()
      }))
    );

    // 4️⃣ Revenue table
    await supabase.from("revenue").insert(
      Array.from({ length: 20 }).map(() => ({
        amount: rand(200, 4000),
        created_at: randomDate()
      }))
    );

    // 5️⃣ Activity
    await supabase.from("activity_log").insert(
      createdUsers.map(({ userId }) => {
        const type = activityTypes[rand(0, activityTypes.length - 1)];
        return {
          user_id: userId,
          user_name: indianNames[rand(0, indianNames.length - 1)],
          type,
          action: getAction(type),
          created_at: randomDate()
        };
      })
    );

    res.json({
      message: "Sample dashboard data inserted successfully!",
      users_created: createdUsers.length
    });

  } catch (err) {
    console.error("Seed Error:", err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
