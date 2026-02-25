import jwt from "jsonwebtoken";
import pool from "../utils/db.js";
import dotenv from "dotenv";
dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || "change-me-in-production";

// middleware/authMiddleware.js

export const verifySupabaseAuth = {
  required: async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader?.startsWith("Bearer ")) {
        return res.status(401).json({ error: "missing_token" });
      }

      const token = authHeader.split(" ")[1];

      // Verify JWT
      let decoded;
      try {
        decoded = jwt.verify(token, JWT_SECRET);
      } catch (jwtErr) {
        console.log("auth error:", jwtErr.message);
        return res.status(401).json({ error: "jwt_invalid" });
      }

      // Fetch full user profile from DB
      const { rows } = await pool.query(
        `SELECT id, email, role, full_name, first_name, last_name, account_status
         FROM profiles WHERE id = $1`,
        [decoded.id]
      );

      if (rows.length === 0) {
        return res.status(401).json({ error: "jwt_invalid" });
      }

      const user = rows[0];

      // Attach user to request (matching Supabase user shape for compatibility)
      req.user = {
        id: user.id,
        email: user.email,
        role: user.role,
        full_name: user.full_name,
        app_metadata: { role: user.role },
        user_metadata: {
          role: user.role,
          full_name: user.full_name,
          first_name: user.first_name,
          last_name: user.last_name,
        },
      };

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
