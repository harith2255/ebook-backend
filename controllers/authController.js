import supabase from "../utils/supabaseClient.js";

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

    /* --------------------------------------------------
       1️⃣ Create user in Supabase Auth
    -------------------------------------------------- */
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

    /* --------------------------------------------------
       2️⃣ Insert into PROFILES table
    -------------------------------------------------- */
    const { error: insertError } = await supabase.from("profiles").insert({
      id: userId,
      email,
      first_name,
      last_name,
      full_name,
      role: "User",
      status: "active",
      plan: "free",
      created_at: new Date().toISOString(),
    });

    if (insertError) {
      console.error("Profile insert error:", insertError);
      return res.status(500).json({ error: "Failed to save user profile" });
    }

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

    /* --------------------------------------------------
       1️⃣ Authenticate with Supabase
    -------------------------------------------------- */
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({
        email,
        password,
      });

    if (loginError) {
      return res.status(400).json({ error: loginError.message });
    }

    const accessToken = loginData.session?.access_token;
    const userId = loginData.user.id;

    /* --------------------------------------------------
       2️⃣ Fetch role from PROFILES table
    -------------------------------------------------- */
    let role = "User";

    const { data: profile, error: profileErr } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", userId)
      .single();

    if (profileErr) {
      console.error("Profile lookup error:", profileErr);
    }

    if (profile?.role) role = profile.role;

    /* --------------------------------------------------
       3️⃣ Super Admin Override
    -------------------------------------------------- */
    if (email === process.env.SUPER_ADMIN_EMAIL) {
      role = "super_admin";
      await supabase.from("profiles").upsert([
        { id: userId, email, role }
      ]);
    }

    return res.status(200).json({
      message: "Login successful",
      user: {
        id: userId,
        email,
        role,
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
    const { error } = await supabase.auth.signOut();
    if (error) return res.status(400).json({ error: error.message });

    return res.status(200).json({ message: "Logged out successfully" });

  } catch (err) {
    console.error("Logout error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
