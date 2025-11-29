import dotenv from "dotenv";
dotenv.config();

import { supabasePublic, supabaseAdmin } from "../utils/supabaseClient.js";

export const verifySupabaseAuth = {
  required: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Missing Authorization header" });
      }

      const token = authHeader.split(" ")[1];
      const { data, error } = await supabasePublic.auth.getUser(token);

      if (error || !data?.user) {
        return res.status(401).json({ error: "Unauthorized: Invalid token" });
      }

      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("status")
        .eq("id", data.user.id)
        .single();

      if (profile?.status === "Suspended") {
        return res.status(403).json({ error: "Your account is suspended" });
      }

      req.user = data.user;
      next();
    } catch (err) {
      console.error("Auth required error:", err);
      res.status(500).json({ error: "Internal server error" });
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
      const { data, error } = await supabasePublic.auth.getUser(token);

      if (error || !data?.user) {
        req.user = null;
        return next();
      }

      req.user = data.user;
      next();
    } catch (err) {
      console.error("Auth optional error:", err);
      req.user = null;
      next();
    }
  },
};

// FIX: correct backward compatibility
export default verifySupabaseAuth; // 👈 THIS IS THE FIX

export async function adminOnly(req, res, next) {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized: No user attached" });
    }

    const email = req.user.email?.toLowerCase();
    const adminEmail = process.env.SUPER_ADMIN_EMAIL?.toLowerCase();

    const metaRole = req.user.app_metadata?.role;
    const userMetaRole = req.user.user_metadata?.role;

    const isAdmin =
      email === adminEmail || metaRole === "admin" || userMetaRole === "admin";

    if (!isAdmin) {
      return res.status(403).json({ error: "Access denied: Admins only" });
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
