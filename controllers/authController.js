import supabase from "../utils/supabaseClient.js";

// 🧩 Register new use
export async function register(req, res) {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required" });
    }

    const { data, error } = await supabase.auth.signUp({ email, password });

    console.log("🔍 Supabase signup response:", data, error);

    if (error) {
      return res.status(400).json({ error: error.message || error });
    }

    return res.status(201).json({
      message: "User registered successfully",
      user: data.user,
    });
  } catch (err) {
    console.error("❌ Unexpected error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}




// 🧠 Login existing user
export async function login(req, res) {
  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) return res.status(400).json({ error: error.message });

    const access_token = data.session?.access_token; // ✅ Define this

    if (!access_token) {
      return res.status(400).json({ error: "Login failed: no access token returned" });
    }

    // Fetch role from profiles
    let role = "user";
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("email", email)
      .single();

    // ✅ Ensure admin role for super admin email
    if (email === process.env.SUPER_ADMIN_EMAIL) {
      role = "super_admin";
      await supabase.from("profiles").upsert([
        {
          id: data.user.id,
          email,
          role: "super_admin",
        },
      ]);
    } else if (profile?.role) {
      role = profile.role;
    }

    console.log(`✅ Login success: ${email} (${role})`);

    return res.status(200).json({
      message: "Login successful",
      user: { id: data.user.id, email, role },
      access_token, // ✅ send the real token here
    });

  } catch (err) {
    console.error("Internal error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}




// 🚪 Logout
export async function logout(req, res) {
  try {
    const { error } = await supabase.auth.signOut();
    if (error) return res.status(400).json({ error: error.message });

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Internal error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
