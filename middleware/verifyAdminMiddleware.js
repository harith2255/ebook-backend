import dotenv from "dotenv";
dotenv.config();

// ✅ Load and validate admin email once at startup
const SUPER_ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL?.trim()?.toLowerCase();

if (!SUPER_ADMIN_EMAIL) {
  console.error("❌ SECURITY WARNING: SUPER_ADMIN_EMAIL not set in .env");
  process.exit(1); // Stop the server immediately if not configured
}

/**
 * ✅ Middleware: Restrict route to admin only (Secure version)
 */
export function adminOnly(req, res, next) {
  try {
    const userEmail = req.user?.email?.trim()?.toLowerCase();

    // ✅ Check if token has a valid user
    if (!userEmail) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // ✅ Compare safely
    if (userEmail !== SUPER_ADMIN_EMAIL) {
      return res.status(403).json({ error: "Forbidden" });
    }

    // ✅ Pass through if all checks pass
    next();
  } catch (err) {
    console.error("Admin middleware error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
}
