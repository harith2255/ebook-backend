import pool from "../utils/db.js";
import supabase from "../utils/supabaseClient.js";
import { supabaseAdmin } from "../utils/supabaseClient.js";

import { logActivity } from "../utils/activityLogger.js";
import crypto from "crypto";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import nodemailer from "nodemailer";

const JWT_SECRET = process.env.JWT_SECRET || "change-me-in-production";
const JWT_EXPIRES_IN = "15d"; // 15 days

export async function register(req, res) {
  try {
    const { first_name, last_name, email, password } = req.body;

    if (!first_name || !last_name || !email || !password) {
      return res.status(400).json({ error: "All fields are required" });
    }

    const full_name = `${first_name} ${last_name}`;

    // Check if email already exists
    const { rows: existing } = await pool.query(
      `SELECT id FROM profiles WHERE email = $1`,
      [email]
    );

    if (existing.length > 0) {
      return res.status(400).json({ error: "User already registered" });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 12);

    // Create user in profiles table
    const { rows } = await pool.query(
      `INSERT INTO profiles (email, password_hash, first_name, last_name, full_name, role, account_status, created_at)
       VALUES ($1, $2, $3, $4, $5, 'User', 'active', NOW())
       RETURNING id, email, full_name, role`,
      [email, password_hash, first_name, last_name, full_name]
    );

    const user = rows[0];

    /* ACTIVITY LOG */
    await logActivity(user.id, full_name, "created an account", "activity");

    return res.status(201).json({
      message: "Account created successfully",
      user: {
        id: user.id,
        email,
        full_name,
        role: "User",
      },
    });
  } catch (err) {
    console.error("Unexpected register error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}


/* =====================================================
   🧠 LOGIN USER  +  DRM LOGGING  +  SUSPENSION CHECK
===================================================== */
export async function login(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password required" });
    }

    /* 1️⃣ Find user by email */
    const { rows } = await pool.query(
      `SELECT id, email, password_hash, account_status, full_name, first_name, last_name, role, must_reset_password
       FROM profiles WHERE email = $1`,
      [email]
    );

    if (rows.length === 0) {
      return res.status(400).json({ error: "Invalid login credentials" });
    }

    const user = rows[0];

    /* 2️⃣ Verify password */
    const passwordValid = await bcrypt.compare(password, user.password_hash);
    if (!passwordValid) {
      return res.status(400).json({ error: "Invalid login credentials" });
    }

    /* 3️⃣ Generate JWT */
    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role || "User",
        full_name: user.full_name,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    const refreshToken = jwt.sign(
      { id: user.id, type: "refresh" },
      JWT_SECRET,
      { expiresIn: "30d" }
    );

    const isSuspended = user.account_status === "suspended";
    const role = user.role || "User";
    const fullName =
      user.full_name ||
      `${user.first_name || ""} ${user.last_name || ""}`.trim();

    /* 4️⃣ Device ID */
    const rawDevice = [
      req.headers["sec-ch-ua-platform"] || "unknown-platform",
      req.headers["user-agent"] || "unknown-agent",
      req.ip || "unknown-ip",
    ].join("|");

    const deviceId = crypto
      .createHash("sha256")
      .update(rawDevice)
      .digest("hex");

    /* 5️⃣ Session expiry */
    const SESSION_DAYS = 15;
    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + SESSION_DAYS * 24 * 60 * 60 * 1000
    );

    // deactivate old sessions
    await supabaseAdmin
      .from("user_sessions")
      .update({ active: false })
      .eq("user_id", user.id);

    // create/update session for this user + device
    const { data: sessionRow, error } = await supabaseAdmin
      .from("user_sessions")
      .upsert(
        {
          user_id: user.id,
          device_id: deviceId,
          active: true,
          last_active: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          device: req.headers["sec-ch-ua-platform"] || "Unknown",
          user_agent: req.headers["user-agent"],
          location: req.ip || "Unknown",
        },
        { onConflict: "user_id,device_id" }
      )
      .select()
      .single();

    if (error) {
      console.error("Session upsert error:", error);
      return res.status(500).json({ error: "Session creation failed" });
    }

    /* 6️⃣ Success */
    return res.json({
      message: isSuspended
        ? "Login successful (Read-only mode)"
        : "Login successful",
      user: {
        id: user.id,
        email,
        role,
        full_name: fullName,
        read_only: isSuspended,
      },
      access_token: accessToken,
      refresh_token: refreshToken,
      session_id: sessionRow.id,
      must_reset_password: user.must_reset_password || false,
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}

/* =====================================================
   🚪 LOGOUT USER (SESSION-BASED)
===================================================== */
export async function logout(req, res) {
  try {
    const sessionId = req.headers["x-session-id"];

    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // 🔒 Invalidate current session ONLY
    if (sessionId) {
      await supabaseAdmin
        .from("user_sessions")
        .update({
          active: false,
          last_active: new Date().toISOString(),
        })
        .eq("id", sessionId)
        .eq("user_id", req.user.id);
    }

    // Activity log
    if (req.user.role === "User") {
      await logActivity(
        req.user.id,
        req.user.full_name || req.user.email,
        "logged out",
        "login"
      );
    }

    // DRM log
    await supabaseAdmin.from("drm_access_logs").insert({
      user_id: req.user.id,
      user_name: req.user.full_name || req.user.email,
      action: "logout",
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
    });

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Logout error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}


/* =====================================================
   📧 FORGOT PASSWORD — sends reset link via email
===================================================== */
export async function forgotPassword(req, res) {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: "Email is required" });
    }

    // Check if user exists
    const { rows } = await pool.query(
      `SELECT id, email, full_name FROM profiles WHERE email = $1`,
      [email.toLowerCase()]
    );

    if (rows.length === 0) {
      // Don't reveal if email exists — always return success
      return res.json({ message: "If this email exists, a reset link has been sent." });
    }

    const user = rows[0];

    // Generate a reset token (valid for 1 hour)
    const resetToken = crypto.randomBytes(32).toString("hex");
    const resetTokenHash = crypto
      .createHash("sha256")
      .update(resetToken)
      .digest("hex");
    const resetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    // Store token in DB
    await pool.query(
      `UPDATE profiles SET reset_token = $1, reset_token_expires = $2 WHERE id = $3`,
      [resetTokenHash, resetExpires.toISOString(), user.id]
    );

    // Build reset URL
    const frontendUrl = process.env.FRONTEND_URL || "http://localhost:3000";
    const resetUrl = `${frontendUrl}/reset-password?token=${resetToken}&email=${encodeURIComponent(email)}`;

    // Send email (or log to console in dev mode)
    if (process.env.SMTP_EMAIL && process.env.SMTP_PASSWORD && process.env.SMTP_EMAIL !== "your-email@gmail.com") {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: process.env.SMTP_EMAIL,
          pass: process.env.SMTP_PASSWORD,
        },
      });

      await transporter.sendMail({
        from: `"E-Book Platform" <${process.env.SMTP_EMAIL}>`,
        to: email,
        subject: "Password Reset Request",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2>Password Reset</h2>
            <p>Hello ${user.full_name || "User"},</p>
            <p>You requested a password reset. Click the button below to set a new password:</p>
            <a href="${resetUrl}" 
               style="display: inline-block; background: #4F46E5; color: white; padding: 12px 24px; 
                      border-radius: 8px; text-decoration: none; margin: 16px 0;">
              Reset Password
            </a>
            <p style="color: #666; font-size: 14px;">This link expires in 1 hour.</p>
            <p style="color: #666; font-size: 14px;">If you didn't request this, ignore this email.</p>
          </div>
        `,
      });
    } else {
      // Dev mode: no real email — log reset link to console
      console.log("\n📧 [DEV MODE] Password reset link:");
      console.log(`   ${resetUrl}\n`);
    }

    return res.json({ message: "If this email exists, a reset link has been sent." });
  } catch (err) {
    console.error("Forgot password error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}


/* =====================================================
   🔑 RESET PASSWORD — verifies token & sets new password
===================================================== */
export async function resetPassword(req, res) {
  try {
    const { token, email, new_password } = req.body;

    if (!token || !email || !new_password) {
      return res.status(400).json({ error: "Token, email, and new password are required" });
    }

    if (new_password.length < 6) {
      return res.status(400).json({ error: "Password must be at least 6 characters" });
    }

    // Hash the incoming token to compare with DB
    const tokenHash = crypto
      .createHash("sha256")
      .update(token)
      .digest("hex");

    // Find user with this token that hasn't expired
    const { rows } = await pool.query(
      `SELECT id, email FROM profiles 
       WHERE email = $1 AND reset_token = $2 AND reset_token_expires > NOW()`,
      [email.toLowerCase(), tokenHash]
    );

    if (rows.length === 0) {
      return res.status(400).json({ error: "Invalid or expired reset token" });
    }

    const user = rows[0];

    // Hash new password and save
    const password_hash = await bcrypt.hash(new_password, 12);

    await pool.query(
      `UPDATE profiles 
       SET password_hash = $1, reset_token = NULL, reset_token_expires = NULL, must_reset_password = false
       WHERE id = $2`,
      [password_hash, user.id]
    );

    return res.json({ message: "Password reset successfully. You can now log in." });
  } catch (err) {
    console.error("Reset password error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
