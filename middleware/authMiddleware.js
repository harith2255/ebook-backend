import { supabasePublic, supabaseAdmin } from "../utils/supabaseClient.js";

import jwt from "jsonwebtoken";
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

      /* -------------------------------------------------
         1️⃣ VERIFY TOKEN (SUPABASE)
      ------------------------------------------------- */
      const { data, error } = await supabasePublic.auth.getUser(token);
      if (error || !data?.user) {
        return res.status(401).json({ error: "Invalid token" });
      }

      req.user = data.user;

      /* -------------------------------------------------
         2️⃣ CHECK ACCOUNT STATUS
      ------------------------------------------------- */
      const { data: profile, error: profileErr } = await supabaseAdmin
        .from("profiles")
        .select("account_status")
        .eq("id", req.user.id)
        .single();

      if (profileErr) throw profileErr;

      if (profile.account_status === "suspended") {
        // 🔐 READ-ONLY MODE
        if (req.method !== "GET") {
          return res.status(403).json({
            error: "Account suspended. Read-only access enabled.",
            mode: "read_only",
          });
        }
      }

      next();
    } catch (err) {
      console.error("Auth middleware error:", err);
      return res.status(500).json({ error: "Internal server error" });
    }
  },

  optional: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith("Bearer ")) {
        req.user = null;
        return next();
      }

      const token = authHeader.split(" ")[1];
      const { data } = await supabasePublic.auth.getUser(token);

      req.user = data?.user || null;
      next();
    } catch (err) {
      req.user = null;
      next();
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
