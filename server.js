import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import bodyParser from "body-parser";
import cron from "node-cron";
import supabase from "./utils/supabaseClient.js";

// 🧩 Import Routes
import authRoutes from "./routes/authRoutes.js";
import bookRoutes from "./routes/bookRoutes.js";
import dashboardRoutes from "./routes/dashboardRoutes.js";
import libraryRoutes from "./routes/libraryRoutes.js";
import mocktestRoutes from "./routes/mocktestRoutes.js";
import notesRoutes from "./routes/notesRoutes.js";
import writingRoutes from "./routes/writingRoutes.js";
import jobRoutes from "./routes/jobRoutes.js";
import profileRoutes from "./routes/profileRoutes.js";
import admindashboardRoutes from "./routes/admin/admindashboardRoutes.js"
import customerRoutes from "./routes/admin/customerRoutes.js";
import contentRoutes from "./routes/admin/contentRoutes.js"
import drmRoutes from "./routes/admin/drmRoutes.js";
import reportsRoutes from "./routes/admin/reportRoutes.js";
import aiRoutes from "./routes/admin/aiRoutes.js";
import notificationRoutes from "./routes/admin/notificationRoutes.js";
dotenv.config();

const app = express();

// 🔧 Middleware
app.use(bodyParser.json());
app.use(
  cors({
    origin: process.env.FRONTEND_URL,
    credentials: true,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));


// 🕒 CRON JOB — Auto-expire mock tests every 5 minutes
cron.schedule("*/5 * * * *", async () => {
  console.log("⏰ [CRON] Checking for expired mock tests...");

  try {
    // 1️⃣ Fetch in-progress attempts with linked test durations
    const { data: attempts, error } = await supabase
      .from("mock_attempts")
      .select("id, started_at, test_id, mock_tests(duration_minutes)")
      .eq("status", "in_progress");

    if (error) throw error;
    if (!attempts?.length) {
      console.log("✅ [CRON] No active mock tests found.");
      return;
    }

    const now = new Date();
    const expiredIds = [];

    // 2️⃣ Check for expiry safely
    for (const attempt of attempts) {
      const started = new Date(attempt.started_at);
      const duration = attempt.mock_tests?.duration_minutes || 0;
      if (!duration) {
        console.warn(`⚠️ [CRON] Attempt ${attempt.id} has missing duration (test_id=${attempt.test_id}).`);
        continue;
      }

      const expiresAt = new Date(started.getTime() + duration * 60000);
      if (now > expiresAt) expiredIds.push(attempt.id);
    }

    // 3️⃣ Auto-close expired attempts
    if (expiredIds.length > 0) {
      const { error: updateError } = await supabase
        .from("mock_attempts")
        .update({
          status: "time_expired",
          completed_at: now,
        })
        .in("id", expiredIds);

      if (updateError) throw updateError;

      console.log(`🕒 [CRON] Auto-closed ${expiredIds.length} expired mock test(s).`);
    } else {
      console.log("✅ [CRON] No expired mock tests yet.");
    }
  } catch (err) {
    console.error("❌ [CRON ERROR]", err.message);
  }
});

// ✅ ROUTES — organized by feature
app.use("/api/auth", authRoutes);
app.use("/api/books", bookRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/library", libraryRoutes);
app.use("/api/mock-tests", mocktestRoutes);
app.use("/api/notes",notesRoutes); 

app.use("/api/writing", writingRoutes);
app.use("/api/content", contentRoutes);

app.use("/api/jobs", jobRoutes);
app.use("/api/profile", profileRoutes);
import testRoutes from "./routes/testRoutes.js";

app.use("/api/test", testRoutes);

app.use("/api/admin",admindashboardRoutes);
app.use("/api/admin/content",contentRoutes);
// report

app.use("/api/admin/reports", reportsRoutes);

import publicContentRoutes from "./routes/publicContentRoutes.js"
app.use("/api/content", publicContentRoutes);


// Admin Customer Management
app.use("/api/admin/customers", customerRoutes);
// drm
app.use("/api/admin/drm", drmRoutes);
// report
app.use("/api/admin/reports",reportsRoutes)
// ai


app.use("/api/admin/ai", aiRoutes);


app.use("/api/admin/notifications", notificationRoutes);

import userNotificationRoutes from "./routes/notificationRoutes.js";

app.use("/api/notifications", userNotificationRoutes);

import seedRoutes from "./routes/admin/seedRoutes.js";

app.use("/api/admin/seed", seedRoutes);


// job
import adminJobRoutes from "./routes/admin/jobRoutes.js"
app.use("/api/admin/jobs",adminJobRoutes)
import systemSettings from "./routes/admin/systemSettingsRoutes.js"
app.use("/api/admin/settings",systemSettings)
import adminWritingServiceRoutes from "./routes/admin/adminWritingServiceRoutes.js"
app.use("/api/admin/writing-service",adminWritingServiceRoutes)

import paymentRoutes from "./routes/admin/paymentRoutes.js";
app.use("/api/admin/payments", paymentRoutes);



// ✅ Base route
app.get("/", (req, res) => {
  res.send("✅ Supabase + Express backend is running successfully 🚀");
});

// ✅ Global Error Handling (optional safety net)
app.use((err, req, res, next) => {
  console.error("🔥 [SERVER ERROR]", err.stack);
  res.status(500).json({ error: "Internal Server Error" });
});

// ✅ Start the server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
