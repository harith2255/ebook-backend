import supabase from "../utils/supabaseClient.js"; // anon
import { supabaseAdmin } from "../utils/supabaseClient.js"; // service role

import { logActivity } from "../utils/activityLogger.js";
import crypto from "crypto";
export async function register(req, res) {
  try {
    const { first_name, last_name, email, password } = req.body;

    if (!first_name || !last_name || !email || !password) {
      return res.status(400).json({ error: "All fields are required" });
    }

    const full_name = `${first_name} ${last_name}`;

    /* 1️⃣ CREATE AUTH USER (this triggers profile creation automatically) */
    const { data: authData, error: authError } =
      await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { first_name, last_name, full_name },
      });

    if (authError) {
      console.error("Auth error:", authError);
      return res.status(400).json({ error: authError.message });
    }

    const userId = authData.user.id;

  
   /* 2️⃣ UPSERT PROFILE (SAFE) */
const { error: profileUpsertError } = await supabaseAdmin
  .from("profiles")
  .upsert({
    id: userId,
    email,
    first_name,
    last_name,
    full_name,
    plan: "free",
    status: "active",
    role: "User",
  });

if (profileUpsertError) {
  console.error("Profile upsert error:", profileUpsertError);
  return res.status(500).json({
    error: "Database error creating new user",
  });
}



    /* 3️⃣ ACTIVITY LOG */
    await logActivity(userId, full_name, "created an account", "activity");

    return res.status(201).json({
      message: "Account created successfully",
      user: {
        id: userId,
        email,
        full_name,
        role: "User",
      },
    });
  } catch (err) {
    console.error("Unexpected register error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}




/* =====================================================
   🧠 LOGIN USER  +  DRM LOGGING  +  SUSPENSION CHECK
===================================================== */
export async function login(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password required" });
    }

    /* 1️⃣ Supabase Auth */
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({ email, password });

    if (loginError) {
      return res.status(400).json({ error: loginError.message });
    }

    const userId = loginData.user.id;
    const accessToken = loginData.session.access_token;

    /* 2️⃣ Profile */
    const { data: profile, error: profileError } =
      await supabaseAdmin
        .from("profiles")
        .select("status, full_name, first_name, last_name, role")
        .eq("id", userId)
        .single();

    if (profileError) {
      return res.status(400).json({ error: profileError.message });
    }

    const isSuspended = profile.status === "Suspended";
    const role = profile.role || "User";

    const fullName =
      profile.full_name ||
      `${profile.first_name || ""} ${profile.last_name || ""}`.trim();

    /* 3️⃣ Device ID */
    const rawDevice = [
      req.headers["sec-ch-ua-platform"] || "unknown-platform",
      req.headers["user-agent"] || "unknown-agent",
      req.ip || "unknown-ip",
    ].join("|");

    const deviceId = crypto
      .createHash("sha256")
      .update(rawDevice)
      .digest("hex");

    /* 4️⃣ Session expiry */
   const SESSION_DAYS = 15;

const now = new Date();
const expiresAt = new Date(
  now.getTime() + SESSION_DAYS * 24 * 60 * 60 * 1000
);

// deactivate old sessions (optional)
await supabaseAdmin
  .from("user_sessions")
  .update({ active: false })
  .eq("user_id", userId);

// create new session
// create/update session for this user + device
const { data: sessionRow, error } = await supabaseAdmin
  .from("user_sessions")
  .upsert(
    {
      user_id: userId,
      device_id: deviceId,
      active: true,
      last_active: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      device: req.headers["sec-ch-ua-platform"] || "Unknown",
      user_agent: req.headers["user-agent"],
      location: req.ip || "Unknown",
    },
    { onConflict: "user_id,device_id" } // VERY IMPORTANT
  )
  .select()
  .single();

if (error) {
  console.error("Session upsert error:", error);
  return res.status(500).json({ error: "Session creation failed" });
}



    /* 7️⃣ Success */
    return res.json({
      message: isSuspended
        ? "Login successful (Read-only mode)"
        : "Login successful",
      user: {
        id: userId,
        email,
        role,
        full_name: fullName,
        read_only: isSuspended,
      },
      access_token: accessToken,
      refresh_token: loginData.session.refresh_token,
      session_id: sessionRow.id,
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}

/* =====================================================
   🚪 LOGOUT USER (SESSION-BASED)
===================================================== */
export async function logout(req, res) {
  try {
    const sessionId = req.headers["x-session-id"];

    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // 🔒 Invalidate current session ONLY
    if (sessionId) {
      await supabaseAdmin
        .from("user_sessions")
        .update({
          active: false,
          last_active: new Date().toISOString(),
        })
        .eq("id", sessionId)
        .eq("user_id", req.user.id);
    }

    // Activity log
    if (req.user.role === "User") {
      await logActivity(
        req.user.id,
        req.user.full_name || req.user.email,
        "logged out",
        "login"
      );
    }

    // DRM log
    await supabaseAdmin.from("drm_access_logs").insert({
      user_id: req.user.id,
      user_name: req.user.full_name || req.user.email,
      action: "logout",
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
    });

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Logout error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}


