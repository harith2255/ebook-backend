import supabase from "../utils/supabaseClient.js";
import dotenv from "dotenv";
import crypto from "crypto";
import bcrypt from "bcrypt";
dotenv.config();

// -------------------------------------------------------------
// 1️⃣ SAMPLE USERS
// -------------------------------------------------------------
const USERS = [
  {
    email: "alice@example.com",
    password: "password123",
    first_name: "Alice",
    last_name: "Johnson",
    role: "user",
    plan: "free",
    status: "active",
  },
  {
    email: "bob@example.com",
    password: "password123",
    first_name: "Bob",
    last_name: "Williams",
    role: "user",
    plan: "premium",
    status: "active",
  },
  {
    email: "carol@example.com",
    password: "password123",
    first_name: "Carol",
    last_name: "Smith",
    role: "admin",
    plan: "enterprise",
    status: "active",
  },
];

// -------------------------------------------------------------
// 2️⃣ SEED HELPERS — Fetch or Create User
// -------------------------------------------------------------
async function ensureUser(u) {
  const { data: existing } = await supabase
    .from("profiles")
    .select("id")
    .eq("email", u.email)
    .maybeSingle();

  if (existing?.id) {
    console.log(`✔ User exists: ${u.email}`);
    return existing.id;
  }

  console.log(`📌 Creating new user: ${u.email}`);
  const password_hash = await bcrypt.hash(u.password, 12);
  const { data, error } = await supabase
    .from("profiles")
    .insert({
      email: u.email,
      password_hash,
      first_name: u.first_name,
      last_name: u.last_name,
      full_name: `${u.first_name} ${u.last_name}`,
      role: u.role || "User",
      account_status: u.status || "active",
      created_at: new Date(),
    })
    .select("id")
    .single();

  if (error) {
    console.error("❌ User create error:", error);
    return null;
  }

  return data.id;
}

async function ensureProfile(userId, u) {
  const { error } = await supabase.from("profiles").upsert({
    id: userId,
    email: u.email,
    first_name: u.first_name,
    last_name: u.last_name,
    full_name: `${u.first_name} ${u.last_name}`,
    role: u.role,
    plan: u.plan,
    status: u.status,
    created_at: new Date(),
  });

  if (!error) console.log(`✔ Profile ready for ${u.email}`);
}

// -------------------------------------------------------------
// 3️⃣ SEED BOOKS
// -------------------------------------------------------------
async function seedBooks() {
  console.log("\n📚 Seeding Books...");

  const books = [
    {
      id: crypto.randomUUID(),
      title: "Mastering React",
      author: "John Doe",
      price: 199,
      description: "A full guide to React development.",
      category: "Programming",
      created_at: new Date(),
    },
    {
      id: crypto.randomUUID(),
      title: "Python for Beginners",
      author: "Jane Smith",
      price: 149,
      description: "Learn Python from scratch.",
      category: "Programming",
      created_at: new Date(),
    },
  ];

  const { error } = await supabase.from("books").insert(books);

  if (!error) console.log("✔ Books inserted");
  return books;
}

// -------------------------------------------------------------
// 4️⃣ SEED NOTES
// -------------------------------------------------------------
async function seedNotes() {
  console.log("\n📝 Seeding Notes...");

  const notes = [
    {
      id: crypto.randomUUID(),
      title: "DSA Notes",
      subject: "Computer Science",
      price: 99,
      created_at: new Date(),
    },
    {
      id: crypto.randomUUID(),
      title: "OS Notes",
      subject: "Computer Science",
      price: 79,
      created_at: new Date(),
    },
  ];

  const { error } = await supabase.from("notes").insert(notes);
  if (!error) console.log("✔ Notes inserted");
  return notes;
}

// -------------------------------------------------------------
// 5️⃣ SEED PAYMENTS
// -------------------------------------------------------------
async function seedPayments(userId) {
  console.log(`💰 Seeding Payments for user ${userId}`);

  const transactions = [
    {
      id: crypto.randomUUID(),
      user_id: userId,
      plan_id: 1,
      amount: 199,
      currency: "INR",
      method: "card",
      status: "Completed",
      description: "Book purchase",
      external_ref: "TXN-" + Date.now(),
      created_at: new Date(),
    },
  ];

  await supabase.from("payments_transactions").insert(transactions);
  console.log("✔ Payments inserted");
}

// -------------------------------------------------------------
// 6️⃣ SEED WRITING SERVICES
// -------------------------------------------------------------
async function seedWritingServices() {
  console.log("\n✍ Seeding Writing Services...");

  const services = [
    {
      id: 1,
      name: "Essay Writing",
      type: "essay",
      description: "Professional academic essays",
      price: 49,
      turnaround: "3 days",
    },
    {
      id: 2,
      name: "Research Paper",
      type: "research",
      description: "Detailed research papers",
      price: 99,
      turnaround: "5 days",
    },
  ];

  await supabase.from("writing_services").upsert(services);
  console.log("✔ Writing services ready");
}

// -------------------------------------------------------------
// 7️⃣ SEED WRITING ORDERS
// -------------------------------------------------------------
async function seedWritingOrders(userId) {
  console.log("\n📄 Seeding Writing Orders...");

  const orders = [
    {
      id: crypto.randomUUID(),
      user_id: userId,
      title: "Climate Change Paper",
      type: "research",
      subject_area: "Science",
      academic_level: "Undergraduate",
      pages: 5,
      deadline: "2025-02-01",
      total_price: 299,
      status: "In Progress",
      created_at: new Date(),
    },
  ];

  await supabase.from("writing_orders").insert(orders);
  console.log("✔ Writing orders inserted");
  return orders;
}

// -------------------------------------------------------------
// 8️⃣ SEED MOCK TESTS
// -------------------------------------------------------------
async function seedMockTests() {
  console.log("\n🧠 Seeding Mock Tests...");

  const tests = [
    {
      id: crypto.randomUUID(),
      title: "JavaScript Fundamentals Test",
      duration_minutes: 30,
      created_at: new Date(),
    },
  ];

  await supabase.from("mock_tests").insert(tests);
  console.log("✔ Mock tests inserted");
  return tests;
}

// -------------------------------------------------------------
// 9️⃣ SEED JOBS
// -------------------------------------------------------------
async function seedJobs() {
  console.log("\n💼 Seeding Jobs...");

  const jobs = [
    {
      id: crypto.randomUUID(),
      title: "Frontend Developer",
      company: "Tech Corp",
      location: "Remote",
      salary: "8 LPA",
      created_at: new Date(),
    },
  ];

  await supabase.from("jobs").insert(jobs);
  console.log("✔ Jobs inserted");
  return jobs;
}

// -------------------------------------------------------------
// 🔟 RUN SEED
// -------------------------------------------------------------
async function runSeed() {
  console.log("\n🚀 Running FULL PROJECT SEED...");

  const bookData = await seedBooks();
  const notesData = await seedNotes();
  await seedWritingServices();
  const jobsData = await seedJobs();
  const mockTests = await seedMockTests();

  for (let user of USERS) {
    const userId = await ensureUser(user);
    if (!userId) continue;

    await ensureProfile(userId, user);
    await seedPayments(userId);
    await seedWritingOrders(userId);
  }

  console.log("\n🎉 FULL PROJECT SEED COMPLETE!");
  process.exit(0);
}

runSeed();
