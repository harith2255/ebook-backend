import { supabasePublic, supabaseAdmin } from "../utils/supabaseClient.js";

import jwt from "jsonwebtoken";
import dotenv from "dotenv";
dotenv.config();

export const verifySupabaseAuth = {
  required: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader?.startsWith("Bearer ")) {
        console.warn("❌ Missing Authorization header");
        return res.status(401).json({ error: "Missing Authorization header" });
      }

      const token = authHeader.split(" ")[1];

      // 1️⃣ Verify Supabase token
      const { data, error } = await supabasePublic.auth.getUser(token);

      if (error || !data?.user) {
        console.warn("❌ Invalid Supabase token", error);
        return res.status(401).json({ error: "Invalid token" });
      }

      req.user = data.user;

      // 2️⃣ Profile lookup
      const { data: profile, error: profileErr } = await supabaseAdmin
        .from("profiles")
        .select("account_status")
        .eq("id", req.user.id)
        .maybeSingle();

      if (profileErr) {
        console.error("🔥 Profile DB error:", profileErr);
        return res.status(500).json({ error: "Profile lookup failed" });
      }

      // 🔥 AUTO-FIX + LOG
      if (!profile) {
        console.warn("⚠️ Profile missing. Auto-creating:", req.user.id);

        const { error: insertErr } = await supabaseAdmin
          .from("profiles")
          .insert({
            id: req.user.id,
            email: req.user.email,
            account_status: "active",
            created_at: new Date().toISOString(),
          });

        if (insertErr) {
          console.error("🔥 Profile auto-create failed:", insertErr);
          return res.status(500).json({ error: "Profile setup failed" });
        }
      }
await supabaseAdmin
  .from("user_sessions")
  .update({ last_active: new Date().toISOString() })
  .eq("user_id", req.user.id)
  .eq("active", true);

      // 3️⃣ Suspension check
      if (profile?.account_status === "suspended" && req.method !== "GET") {
        console.warn("🚫 Suspended user attempted write:", req.user.id);
        return res.status(403).json({
          error: "Account suspended. Read-only access enabled.",
        });
      }
      next();
    } catch (err) {
      console.error("🔥 Auth middleware crash:", err);
      return res.status(500).json({ error: "Internal server error" });
    }
  },
};


// FIX: correct backward compatibility
export default verifySupabaseAuth; // 👈 THIS IS THE FIX

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
