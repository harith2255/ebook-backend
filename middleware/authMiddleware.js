import { supabasePublic, supabaseAdmin } from "../utils/supabaseClient.js";
import dotenv from "dotenv";
dotenv.config();

export const verifySupabaseAuth = {
  required: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader?.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Missing Authorization header" });
      }

      const token = authHeader.split(" ")[1];

      /* ===============================
         1️⃣ Verify Supabase token
      =============================== */
      const { data, error } = await supabasePublic.auth.getUser(token);

      if (error || !data?.user) {
        return res.status(401).json({ error: "Invalid token" });
      }

      req.user = data.user;

      /* ===============================
         2️⃣ Fetch profile
      =============================== */
      let { data: profile, error: profileErr } = await supabaseAdmin
        .from("profiles")
        .select("account_status")
        .eq("id", req.user.id)
        .maybeSingle();

      if (profileErr) {
        console.error("Profile fetch failed:", profileErr);
        return res.status(500).json({ error: "Profile lookup failed" });
      }

      /* ===============================
         3️⃣ Auto-create profile (SAFE)
      =============================== */
      if (!profile) {
        const { error: insertErr } = await supabaseAdmin
          .from("profiles")
          .insert({
            id: req.user.id,
            email: req.user.email ?? null,
            account_status: "active",
          });

        if (insertErr) {
          console.error("Profile auto-create failed:", insertErr);
          return res.status(500).json({ error: "Profile setup failed" });
        }

        // Re-fetch profile
        const refetch = await supabaseAdmin
          .from("profiles")
          .select("account_status")
          .eq("id", req.user.id)
          .single();

        profile = refetch.data;
      }

      /* ===============================
         4️⃣ Update session activity
      =============================== */
      await supabaseAdmin
        .from("user_sessions")
        .update({ last_active: new Date().toISOString() })
        .eq("user_id", req.user.id)
        .eq("active", true);

      /* ===============================
         5️⃣ Suspension check
      =============================== */
      if (profile?.account_status === "suspended" && req.method !== "GET") {
        return res.status(403).json({
          error: "Account suspended. Read-only access enabled.",
        });
      }

      next();
    } catch (err) {
      console.error("Auth middleware crash:", err);
      return res.status(500).json({ error: "Internal server error" });
    }
  },
};

export default verifySupabaseAuth;


export function adminOnly(req, res, next) {
  try {
    const SUPER_ADMIN_EMAIL =
      process.env.SUPER_ADMIN_EMAIL?.trim()?.toLowerCase();

    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized: No user" });
    }

    const email = req.user.email?.toLowerCase();
    const metaRole = req.user.app_metadata?.role;
    const userMetaRole = req.user.user_metadata?.role;

    const isAdmin =
      email === SUPER_ADMIN_EMAIL ||
      metaRole === "admin" ||
      userMetaRole === "admin";

    if (!isAdmin) {
      return res.status(403).json({ error: "Admins only" });
    }

    next();
  } catch (err) {
    console.error("Admin check error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
}

export function verify(req, res, next) {
  return verifySupabaseAuth.required(req, res, next);
}
