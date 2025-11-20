import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import bodyParser from "body-parser";
import cron from "node-cron";
import supabase from "./utils/supabaseClient.js";

dotenv.config();
const app = express();

// ---------- Middleware ----------
app.use(bodyParser.json());
app.use(
  cors({
    origin: process.env.FRONTEND_URL,
    credentials: true,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// cors
app.use(
  cors({
    origin: [
      "http://localhost:3000",
      "http://localhost:3001",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:3001"
    ],
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"]
  })
);

// ---------- CRON JOB ----------
cron.schedule("*/5 * * * *", async () => {
  console.log("⏰ [CRON] Checking for expired mock tests...");

  try {
    const { data: attempts, error } = await supabase
      .from("mock_attempts")
      .select("id, started_at, test_id, mock_tests(duration_minutes)")
      .eq("status", "in_progress");

    if (error) throw error;
    if (!attempts?.length) return;

    const now = new Date();
    const expiredIds = [];

    for (const attempt of attempts) {
      const started = new Date(attempt.started_at);
      const duration = attempt.mock_tests?.duration_minutes || 0;
      const expiresAt = new Date(started.getTime() + duration * 60000);

      if (now > expiresAt) expiredIds.push(attempt.id);
    }

    if (expiredIds.length > 0) {
      await supabase
        .from("mock_attempts")
        .update({
          status: "time_expired",
          completed_at: now,
        })
        .in("id", expiredIds);

      console.log(`🕒 Auto-closed ${expiredIds.length} expired test(s).`);
    }
  } catch (err) {
    console.error("❌ [CRON ERROR]", err.message);
  }
});

// ---------- Routes ----------
import authRoutes from "./routes/authRoutes.js";
import bookRoutes from "./routes/bookRoutes.js";          // ⭐ PUBLIC BOOKS
import dashboardRoutes from "./routes/dashboardRoutes.js";
import libraryRoutes from "./routes/libraryRoutes.js";
import mocktestRoutes from "./routes/mocktestRoutes.js";
import notesRoutes from "./routes/notesRoutes.js";
import writingRoutes from "./routes/writingRoutes.js";
import jobRoutes from "./routes/jobRoutes.js";
import profileRoutes from "./routes/profileRoutes.js";
import purchaseRoutes from "./routes/purchaseRoutes.js";  // ⭐ PURCHASE
import testRoutes from "./routes/testRoutes.js";

// ---------- Admin Routes ----------
import admindashboardRoutes from "./routes/admin/admindashboardRoutes.js";
import customerRoutes from "./routes/admin/customerRoutes.js";
import contentRoutes from "./routes/admin/contentRoutes.js";   // ⭐ UPLOAD CONTENT
import drmRoutes from "./routes/admin/drmRoutes.js";
import reportsRoutes from "./routes/admin/reportRoutes.js";
import aiRoutes from "./routes/admin/aiRoutes.js";
import notificationRoutes from "./routes/admin/notificationRoutes.js";
import seedRoutes from "./routes/admin/seedRoutes.js";
import adminJobRoutes from "./routes/admin/jobRoutes.js";
import systemSettings from "./routes/admin/systemSettingsRoutes.js";
import adminWritingServiceRoutes from "./routes/admin/adminWritingServiceRoutes.js";

// ---------- PUBLIC CONTENT (user side) ----------
import publicContentRoutes from "./routes/publicContentRoutes.js";

// ---------------- Route Registrations ----------------
app.use("/api/auth", authRoutes);

// ⭐ PUBLIC BOOKS (used in Explore page)
app.use("/api/books", bookRoutes);

// ⭐ USER PURCHASE
app.use("/api/purchase", purchaseRoutes);

// Regular user routes
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/library", libraryRoutes);
app.use("/api/mock-tests", mocktestRoutes);
app.use("/api/notes", notesRoutes);
app.use("/api/writing", writingRoutes);
app.use("/api/jobs", jobRoutes);
app.use("/api/profile", profileRoutes);
app.use("/api/test", testRoutes);

// ⭐ ADMIN ROUTES
app.use("/api/admin", admindashboardRoutes);
app.use("/api/admin/customers", customerRoutes);
app.use("/api/admin/content", contentRoutes);   // upload list delete edit
app.use("/api/admin/drm", drmRoutes);
app.use("/api/admin/reports", reportsRoutes);
app.use("/api/admin/ai", aiRoutes);
app.use("/api/admin/notifications", notificationRoutes);
app.use("/api/admin/seed", seedRoutes);
app.use("/api/admin/jobs", adminJobRoutes);
app.use("/api/admin/settings", systemSettings);
app.use("/api/admin/writing-service", adminWritingServiceRoutes);
import adminPaymentsRoutes from "./routes/admin/paymentRoutes.js"
app.use("/api/admin/payments",adminPaymentsRoutes)

// ⭐ PUBLIC CONTENT FOR USERS (notes, mocktests)
app.use("/api/content", publicContentRoutes);


import subscriptionsRoutes from "./routes/subscriptionRoutes.js";
import paymentsRoutes from "./routes/paymentRoutes.js";

app.use("/api/subscriptions", subscriptionsRoutes);
app.use("/api/payments", paymentsRoutes);

import { cartRouter } from "./routes/cartRoutes.js";

app.use("/api/cart", cartRouter);

import notificationsRoutes from "./routes/notificationRoutes.js";

app.use("/api/notifications", notificationsRoutes);




// Base Route
app.get("/", (req, res) => {
  res.send("✅ Backend running successfully 🚀");
});


// Error Handler
app.use((err, req, res, next) => {
  console.error("🔥 SERVER ERROR", err.stack);
  res.status(500).json({ error: "Internal Server Error" });
});

// Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
