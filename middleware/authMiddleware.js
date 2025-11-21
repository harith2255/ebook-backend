import { supabasePublic } from "../utils/supabaseClient.js"; // ✅ Use the public client for auth verification
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
 * ADMIN ONLY access
 * Works only if:
 *   1. User email matches SUPER_ADMIN_EMAIL
 *   2. OR user has metadata { role: 'admin' }
 */
export async function adminOnly(req, res, next) {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized: No user attached" });
    }

    const email = req.user.email?.toLowerCase();
    const adminEmail = process.env.SUPER_ADMIN_EMAIL?.toLowerCase();

    const metaRole = req.user.app_metadata?.role; // set manually in Supabase
    const userMetaRole = req.user.user_metadata?.role; // optional

    const isAdmin =
      email === adminEmail ||
      metaRole === "admin" ||
      userMetaRole === "admin";

    if (!isAdmin) {
      return res.status(403).json({ error: "Access denied: Admins only" });
    }

    return next();
  } catch (err) {
    console.error("Admin check error:", err.message);
    res.status(500).json({ error: "Internal server error" });
  }
}
