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
         1️⃣ TRY SUPABASE JWT FIRST
      ------------------------------------------------- */
      const { data } = await supabasePublic.auth.getUser(token);

      if (data?.user) {
        req.user = data.user;
        return next();
      }

      /* -------------------------------------------------
         2️⃣ FALL BACK TO YOUR CUSTOM app_token
      ------------------------------------------------- */
      const decoded = jwt.decode(token);

      if (!decoded || !decoded.user) {
        return res.status(401).json({ error: "Invalid token format" });
      }

      req.user = {
        id: decoded.user.id,
        email: decoded.user.email,
        user_metadata: decoded.user.user_metadata || {},
      };

      return next();

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
      if (data?.user) {
        req.user = data.user;
        return next();
      }

      const decoded = jwt.decode(token);
      req.user = decoded?.user || null;

      next();

    } catch (err) {
      console.error("Auth optional error:", err);
      req.user = null;
      next();
    }
  }
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
