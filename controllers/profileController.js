import supabase from "../utils/pgClient.js";
import { supabaseAdmin } from "../utils/pgClient.js";
import sharp from "sharp";
import bcrypt from "bcrypt";
import pool from "../utils/db.js";
import fs from "fs";
import path from "path";

/* ============================================================================
   1. UPLOAD AVATAR
   POST /api/profile/avatar
============================================================================ */
export const uploadAvatar = async (req, res) => {
  try {
    const userId = req.user.id;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    // Optimize image (resize + compress)
    const optimized = await sharp(req.file.buffer)
      .resize(300, 300)
      .png()
      .toBuffer();

    const filename = `${userId}-${Date.now()}.png`;
    const uploadDir = path.join(process.cwd(), "uploads", "avatars");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, optimized);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/avatars/${filename}`;

    // Save avatar URL to DB
    await supabase
      .from("profiles")
      .update({ avatar_url: publicUrl })
      .eq("id", userId);

    res.json({
      message: "Avatar updated successfully",
      avatar_url: publicUrl,
    });
  } catch (err) {
    console.error("UPLOAD ERROR:", err);
    res.status(500).json({ error: "Failed to upload avatar" });
  }
};

/* ============================================================================
   2. GET USER PROFILE (profile + security + preferences)
   GET /api/profile
============================================================================ */
export const getUserProfile = async (req, res) => {
  const userId = req.user.id;

  // Load profile
  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr)
    return res.status(400).json({ error: profileErr.message });

  // Load preferences
  const { data: preferences } = await supabase
    .from("user_preferences")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  // Load security (2FA)
  const { data: security } = await supabase
    .from("user_security")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  res.json({
    profile,
    security: {
      two_factor_enabled: security?.two_factor_enabled || false,
      method: security?.two_factor_method || "none",
    },
    preferences: preferences || {},
  });
};

/* ============================================================================
   3. UPDATE PROFILE INFORMATION
   PUT /api/profile
============================================================================ */
export const updateUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const allowedFields = [
      "first_name",
      "last_name",
      "email",
      "phone",
      "dob",
      "institution",
      "field_of_study",
      "academic_level",
      "bio",
      "avatar_url",
    ];

    const payload = {};
    for (const key of allowedFields) {
      if (req.body[key] !== undefined) {
        payload[key] = req.body[key];
      }
    }

    /* 🔥 RECOMPUTE FULL NAME */
    if (payload.first_name !== undefined || payload.last_name !== undefined) {
      const { data: current } = await supabase
        .from("profiles")
        .select("first_name, last_name")
        .eq("id", userId)
        .single();

      const first = payload.first_name ?? current.first_name ?? "";
      const last = payload.last_name ?? current.last_name ?? "";

      payload.full_name = `${first} ${last}`.trim();
    }

    const { data, error } = await supabase
      .from("profiles")
      .update(payload)
      .eq("id", userId)
      .select()
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({
      message: "Profile updated",
      profile: data,
    });
  } catch (err) {
    console.error("UPDATE PROFILE ERROR:", err);
    return res.status(500).json({ error: "Unable to update profile" });
  }
};


/* ============================================================================
   4. CHANGE PASSWORD (Supabase Auth)
   PUT /api/profile/security/password
============================================================================ */
export const changePassword = async (req, res) => {
  try {
    const userId = req.user.id; // from your JWT middleware
    const { new_password } = req.body;

    if (!new_password) {
      return res.status(400).json({ error: "New password required" });
    }

    // Hash and update password directly in DB
    const password_hash = await bcrypt.hash(new_password, 12);
    const { error } = await supabaseAdmin
      .from("profiles")
      .update({ password_hash })
      .eq("id", userId);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    return res.json({ message: "Password updated successfully" });
  } catch (err) {
    console.error("SERVER ERROR:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};

/* ============================================================================
   5. UPDATE NOTIFICATION SETTINGS (Stored inside profiles)
   PUT /api/profile/notifications
============================================================================ */
export const updateNotifications = async (req, res) => {
  const userId = req.user.id;

  const { email_notifications, push_notifications } = req.body;

  const { error } = await supabase
    .from("profiles")
    .update({
      email_notifications: email_notifications || {},
      push_notifications: push_notifications || {},
    })
    .eq("id", userId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Notification settings updated" });
};

/* ============================================================================
   6. GET ACTIVE SESSIONS
   GET /api/profile/sessions
============================================================================ */
export const getSessions = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_sessions")
    .select("*")
    .eq("user_id", userId)
    .eq("active", true);

  if (error) return res.status(400).json({ error: error.message });

  res.json(data || []);
};

/* ============================================================================
   7. REVOKE SESSION
   DELETE /api/profile/sessions/:id
============================================================================ */
export const revokeSession = async (req, res) => {
  const userId = req.user.id;
  const { id } = req.params;

  const currentSessionId = req.headers["x-session-id"];

  const { error } = await supabaseAdmin
    .from("user_sessions")
    .update({ active: false })
    .eq("id", id)
    .eq("user_id", userId);

  if (error) {
    return res.status(400).json({ error: error.message });
  }

  res.json({
    message: "Session revoked",
    revoked_current: id === currentSessionId, // 🔥 KEY LINE
  });
};


/* ============================================================================
   8. TOGGLE TWO-FACTOR AUTH (2FA)
   PUT /api/profile/security/2fa
============================================================================ */
export const toggleTwoFactor = async (req, res) => {
  const userId = req.user.id;
  const { enabled, method } = req.body;

  const { error } = await supabase
    .from("user_security")
    .upsert({
      user_id: userId,
      two_factor_enabled: enabled,
      two_factor_method: enabled ? method : "none",
      updated_at: new Date().toISOString(),
    });

  if (error) return res.status(400).json({ error: error.message });

  res.json({
    message: `Two-Factor Authentication ${enabled ? "enabled" : "disabled"}`,
  });
};

/* ============================================================================
   9. UPDATE PREFERENCES (theme, timezone, language)
   PUT /api/profile/preferences
============================================================================ */
export const updatePreferences = async (req, res) => {
  const userId = req.user.id;

  const payload = {
    ...req.body,
    user_id: userId,
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("user_preferences")
    .upsert(payload, { onConflict: "user_id" });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Preferences updated" });
};
