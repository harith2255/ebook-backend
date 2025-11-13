import { supabasePublic } from "../utils/supabaseClient.js"; // ✅ Use the public client for auth verification
import jwt from "jsonwebtoken";
import dotenv from "dotenv";

dotenv.config();

/**
 * ✅ Middleware: Verify Supabase-authenticated OR app-authenticated user
 */
// middleware/authMiddleware.js

export async function verifySupabaseAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader)
      return res.status(401).json({ error: "Missing Authorization header" });


    const token = authHeader.split(" ")[1];
    if (!token)
      return res.status(401).json({ error: "Invalid token format" });

    // ✅ Verify Supabase token
    const { data, error } = await supabasePublic.auth.getUser(token);

    if (error || !data?.user) {
      console.error("❌ Supabase auth failed:", error?.message);
      return res.status(401).json({ error: "Unauthorized: Invalid or expired token" });
    }

    // ✅ Attach user info to request
    req.user = data.user;
    console.log("✅ Auth verified for:", data.user.email);
    next();
  } catch (err) {
    console.error("Auth middleware error:", err.message);
    res.status(500).json({ error: "Internal server error" });
  }
}

/**
 * ✅ Middleware: Restrict route to Admin users only
 */
export async function adminOnly(req, res, next) {
  try {
    if (!req.user)
      return res.status(401).json({ error: "Unauthorized: No user attached" });

    const supabaseRole = req.user.app_metadata?.role;
    const appRole = req.user.role;

    if (
      req.user.email === process.env.SUPER_ADMIN_EMAIL ||
      supabaseRole === "admin" ||
      appRole === "admin"
    ) {
      return next(); // ✅ Authorized
    }

    return res.status(403).json({ error: "Access denied: Admins only" });
  } catch (err) {
    console.error("Admin check error:", err.message);
    res.status(500).json({ error: "Internal server error" });
  }
}
