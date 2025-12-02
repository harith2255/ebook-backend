import supabase from "../utils/supabaseClient.js";
import { logActivity } from "../utils/activityLogger.js";

/* =====================================================
   🧠 REGISTER NEW USER
===================================================== */
export async function register(req, res) {
  try {
    const { first_name, last_name, email, password } = req.body;

    if (!first_name || !last_name || !email || !password) {
      return res.status(400).json({ error: "All fields are required" });
    }

    const full_name = `${first_name} ${last_name}`;

    // Create Supabase Auth User
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { first_name, last_name, full_name } },
    });

    if (authError) return res.status(400).json({ error: authError.message });

    const userId = authData.user.id;

    // Insert into PROFILES table
    const { error: insertError } = await supabase.from("profiles").insert({
      id: userId,
      email,
      first_name,
      last_name,
      full_name,
      role: "User",
      status: "Active",
      plan: "free",
    });

    if (insertError) {
      console.error("Profile insert error:", insertError);
      return res.status(500).json({ error: "Failed to save user profile" });
    }

    // Log Activity
    await logActivity(userId, full_name, "created an account", "activity");

    return res.status(201).json({
      message: "Account created successfully",
      user: {
        id: userId,
        first_name,
        last_name,
        full_name,
        email,
        role: "User",
      },
    });
  } catch (err) {
    console.error("Unexpected register error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}

/* =====================================================
   🧠 LOGIN USER  +  DRM LOGGING ADDED HERE
===================================================== */
export async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password)
      return res.status(400).json({ error: "Email and password required" });

    // Authenticate
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({ email, password });

    if (loginError) return res.status(400).json({ error: loginError.message });

    const userId = loginData.user.id;
    const accessToken = loginData.session?.access_token;

    // Fetch profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, first_name, last_name, role, email")
      .eq("id", userId)
      .single();

    let role = profile?.role || "User";

    // Super admin override
   if (email === process.env.SUPER_ADMIN_EMAIL) {
  role = "super_admin";

  // Add role to JWT claims (app_metadata)
  const { error: metadataError } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { role: "super_admin" }
  });

  if (metadataError) {
    console.error("Metadata update error:", metadataError);
  }

  // Keep profiles table in sync
  await supabase.from("profiles").upsert([{ id: userId, role }]);
}



    const fullName =
      profile?.full_name ||
      `${profile?.first_name || ""} ${profile?.last_name || ""}`.trim() ||
      email;

    // NORMAL USER ACTIVITY
    if (role === "User") {
      await logActivity(userId, fullName, "logged in", "login");
    }

    /* ==========================================================
       ⭐ NEW: DRM ACCESS LOGGING (LOGIN)
    =========================================================== */
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: fullName,
      action: "login",
      book_id: null,
      book_title: null,
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
    });

    // Response

    return res.status(200).json({
      message: "Login successful",
      user: { id: userId, email, role, full_name: fullName },

      // always provide the correct token fields
      access_token: accessToken,
      token: accessToken, // universal
      refresh_token: loginData.session?.refresh_token,
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
    const { user } = req;

    // Supabase logout
    const { error } = await supabase.auth.signOut();
    if (error) return res.status(400).json({ error: error.message });

    // Activity Log
    if (user && user.role === "User") {
      await logActivity(
        user.id,
        user.full_name || user.email,
        "logged out",
        "login"
      );
    }

    /* ==========================================================
       ⭐ NEW: DRM ACCESS LOGGING (LOGOUT)
    =========================================================== */
    if (user) {
      await supabase.from("drm_access_logs").insert({
        user_id: user.id,
        user_name: user.full_name || user.email,
        action: "logout",
        book_id: null,
        book_title: null,
        device_info: req.headers["user-agent"],
        ip_address: req.ip,
        created_at: new Date(),
      });
    }

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Logout error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
