import supabase from "../utils/supabaseClient.js"; // anon
import { supabaseAdmin } from "../utils/supabaseClient.js"; // service role

import { logActivity } from "../utils/activityLogger.js";

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

    /* 2️⃣ UPDATE PROFILE (DO NOT INSERT) */
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
    if (!email || !password)
      return res.status(400).json({ error: "Email and password required" });

    // ✅ USER LOGIN (anon client)
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({ email, password });

    if (loginError)
      return res.status(400).json({ error: loginError.message });

    const userId = loginData.user.id;
    const accessToken = loginData.session.access_token;

    // ✅ PROFILE FETCH (admin)
    const { data: profile, error: profileError } =
      await supabaseAdmin
        .from("profiles")
        .select("status, full_name, first_name, last_name, role, email")
        .eq("id", userId)
        .single();

    if (profileError)
      return res.status(400).json({ error: profileError.message });

    const isSuspended = profile.status === "Suspended";
    let role = profile.role || "User";

    // Super admin override
    if (email === process.env.SUPER_ADMIN_EMAIL) {
      role = "super_admin";
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        app_metadata: { role },
      });
      await supabaseAdmin.from("profiles").upsert({ id: userId, role });
    }

    const fullName =
      profile.full_name ||
      `${profile.first_name || ""} ${profile.last_name || ""}`.trim();

    if (role === "User") {
      await logActivity(userId, fullName, "logged in", "login");
    }

    // DRM login log
    await supabaseAdmin.from("drm_access_logs").insert({
      user_id: userId,
      user_name: fullName,
      action: "login",
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
    });

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
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}



/* =====================================================
   🚪 LOGOUT USER + DRM LOGGING ADDED HERE
===================================================== */
export async function logout(req, res) {
  try {
    const accessToken =
      req.headers.authorization?.replace("Bearer ", "");

    if (!accessToken) {
      return res.status(400).json({ error: "No token provided" });
    }

    const { error } = await supabase.auth.signOut({
      accessToken,
    });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Activity log
    if (req.user && req.user.role === "User") {
      await logActivity(
        req.user.id,
        req.user.full_name || req.user.email,
        "logged out",
        "login"
      );
    }

    // DRM log
    await supabaseAdmin.from("drm_access_logs").insert({
      user_id: req.user?.id,
      user_name: req.user?.full_name || req.user?.email,
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

