import supabase from "../utils/supabaseClient.js";
import { logActivity } from "../utils/activityLogger.js";

/* =====================================================
   🧩 REGISTER NEW USER
===================================================== */
export async function register(req, res) {
  try {
    const { first_name, last_name, email, password } = req.body;

    if (!first_name || !last_name || !email || !password) {
      return res.status(400).json({ error: "All fields are required" });
    }

    const full_name = `${first_name} ${last_name}`;

    // 1️⃣ Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { first_name, last_name, full_name }
      }
    });

    if (authError) {
      return res.status(400).json({ error: authError.message });
    }

    const userId = authData.user.id;

    // 2️⃣ Insert into PROFILES table
    const { error: insertError } = await supabase.from("profiles").insert({
      id: userId,
      email,
      first_name,
      last_name,
      full_name,
      role: "User",
      status: "active",
      plan: "free",
    });

    if (insertError) {
      console.error("Profile insert error:", insertError);
      return res.status(500).json({ error: "Failed to save user profile" });
    }

    // 3️⃣ Log activity (normal users only — register always creates Users)
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
   🧠 LOGIN USER
===================================================== */
export async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password required" });
    }

    // 1️⃣ Authenticate
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({ email, password });

    if (loginError) {
      return res.status(400).json({ error: loginError.message });
    }

    const userId = loginData.user.id;
    const accessToken = loginData.session?.access_token;

    // 2️⃣ Fetch profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, first_name, last_name, role, email")
      .eq("id", userId)
      .single();

    let role = profile?.role || "User";

    // 3️⃣ Super admin override
    if (email === process.env.SUPER_ADMIN_EMAIL) {
      role = "super_admin";
      await supabase.from("profiles").upsert([{ id: userId, email, role }]);
    }

    // 4️⃣ Full Name generation
    const userFullName =
      profile?.full_name ||
      `${profile?.first_name || ""} ${profile?.last_name || ""}`.trim() ||
      email;

    // 5️⃣ Log activity ONLY for normal users
    if (role !== "admin" && role !== "super_admin") {
      await logActivity(userId, userFullName, "logged in", "login");
    }

    // 6️⃣ Return success
    return res.status(200).json({
      message: "Login successful",
      user: {
        id: userId,
        email,
        role,
        full_name: userFullName,
      },
      access_token: accessToken,
    });

  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}

/* =====================================================
   🚪 LOGOUT USER
===================================================== */
export async function logout(req, res) {
  try {
    const { user } = req;

    const { error } = await supabase.auth.signOut();
    if (error) return res.status(400).json({ error: error.message });

    // 1️⃣ Log logout only for normal users
    if (user && user.role !== "admin" && user.role !== "super_admin") {
      await logActivity(
        user.id,
        user.full_name || user.email || "Unknown User",
        "logged out",
        "login"
      );
    }

    return res.status(200).json({ message: "Logged out successfully" });

  } catch (err) {
    console.error("Logout error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
