import { supabasePublic, supabaseAdmin } from "../utils/supabaseClient.js";
import dotenv from "dotenv";
dotenv.config();
const SESSION_TTL_DAYS = 15;
const SESSION_TTL_MS = 60* 1000; // 1 minute

// middleware/authMiddleware.js

export const verifySupabaseAuth = {
  required: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader?.startsWith("Bearer ")) {
        return res.status(401).json({ error: "missing_token" });
      }

      const token = authHeader.split(" ")[1];

      // ⭐ Correct usage for Supabase v2
      const { data, error } = await supabasePublic.auth.getUser(token);

      if (error || !data?.user) {
        console.log("auth error:", error);
        return res.status(401).json({ error: "jwt_invalid" });
      }

      req.user = data.user;
      next();
    } catch (err) {
      console.error("Auth crash:", err);
      return res.status(500).json({ error: "auth_error" });
    }
  },
};





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
