import jwt from "jsonwebtoken";
import pool from "../utils/db.js";

const JWT_SECRET = process.env.JWT_SECRET || "change-me-in-production";

export async function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Missing token" });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // Fetch user from DB
    const { rows } = await pool.query(
      `SELECT id, email, role, full_name FROM profiles WHERE id = $1`,
      [decoded.id]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: "Invalid token" });
    }

    req.user = rows[0];
    next();
  } catch (err) {
    return res.status(401).json({ error: "Invalid token" });
  }
}
