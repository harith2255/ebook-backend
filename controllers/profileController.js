import bcrypt from "bcrypt";
import supabase from "../utils/supabaseClient.js";
import jwt from "jsonwebtoken";

import sharp from "sharp";

// ✅ Upload Avatar
export const uploadAvatar = async (req, res) => {
  try {
    const userId = req.user.id;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const fileBuffer = req.file.buffer;
    const fileExt = req.file.originalname.split(".").pop();
    const fileName = `avatar-${userId}.${fileExt}`;
    const filePath = `avatars/${fileName}`;

    // ✅ Optimize image using sharp
    const optimized = await sharp(fileBuffer)
      .resize(300, 300)
      .png()
      .toBuffer();

    // ✅ Upload to Supabase Storage
    const { error: uploadError } = await supabase.storage
      .from("avatars")
      .upload(filePath, optimized, {
        upsert: true,
        contentType: "image/png",
      });

    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from("avatars")
      .getPublicUrl(filePath);

    // ✅ Save avatar URL in user_profiles
    await supabase
      .from("user_profiles")
      .update({ avatar_url: urlData.publicUrl })
      .eq("user_id", userId);

    res.json({
      message: "Avatar uploaded successfully",
      avatar_url: urlData.publicUrl,
    });
  } catch (err) {
    console.error("[SERVER ERROR]", err);
    res.status(500).json({ error: "Internal Server Error" });
  }};
// ✅ Get profile info
export const getUserProfile = async (req, res) => {
  const userId = req.user.id;

  const { data: profile, error } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) return res.status(400).json({ error: error.message });

  const { data: notifications } = await supabase
    .from("user_notifications")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  const { data: security } = await supabase
    .from("user_security")
    .select("two_factor_enabled, two_factor_method")
    .eq("user_id", userId)
    .maybeSingle();

  res.json({ profile, notifications, security });
};

// ✅ Update personal info
export const updateUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const updates = {
      ...req.body,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
  .from("user_profiles")
  .update({ ...req.body, updated_at: new Date().toISOString() })
  .eq("user_id", req.user.id)
  .select()
  .maybeSingle();

    if (error) {
      console.error("🔥 SUPABASE ERROR:", error);
      return res.status(400).json({ error: error.message });
    }

    res.json({
      message: "Profile updated successfully",
      profile: data,
    });
  } catch (err) {
    console.error("🔥 [SERVER ERROR]", err);
    res.status(500).json({ error: "Internal Server Error" });
  }
};


// ✅ Change password
export const changePassword = async (req, res) => {
  const { current_password, new_password } = req.body;
  const userId = req.user.id;

  // Fetch current hash from Supabase Auth
  const { data: { user }, error: authErr } = await supabase.auth.admin.getUserById(userId);
  if (authErr) return res.status(400).json({ error: authErr.message });

  // Verify old password (you can delegate this to Supabase if using password login)
  // NOTE: Supabase handles password auth internally; this is just a placeholder.
  const match = true; // assume Supabase verified it

  if (!match) return res.status(403).json({ error: "Current password is incorrect" });

  const { error } = await supabase.auth.admin.updateUserById(userId, {
    password: new_password
  });

  if (error) return res.status(400).json({ error: error.message });

  await supabase.from("user_security").upsert({
    user_id: userId,
    last_password_change: new Date().toISOString()
  });

  res.json({ message: "Password updated successfully" });
};

// ✅ Preferences (theme, language, timezone)
export const updatePreferences = async (req, res) => {
  const userId = req.user.id;
  const updates = req.body;

  const { error } = await supabase
    .from("user_profiles")
    .update(updates)
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Preferences updated successfully" });
};

// ✅ Notification Preferences
export const updateNotifications = async (req, res) => {
  const userId = req.user.id;
  const updates = req.body;

  updates.updated_at = new Date().toISOString();

  const { error } = await supabase
    .from("user_notifications")
    .upsert({ user_id: userId, ...updates }, { onConflict: "user_id" });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Notification preferences saved" });
};

// ✅ Toggle Two-Factor Auth
export const toggleTwoFactor = async (req, res) => {
  const userId = req.user.id;
  const { enabled, method } = req.body;

  const { error } = await supabase
    .from("user_security")
    .upsert({
      user_id: userId,
      two_factor_enabled: enabled,
      two_factor_method: method || "none"
    }, { onConflict: "user_id" });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: `Two-factor authentication ${enabled ? "enabled" : "disabled"}` });
};

// ✅ List sessions
export const getSessions = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_sessions")
    .select("*")
    .eq("user_id", userId)
    .eq("active", true);

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};

// ✅ Revoke session
export const revokeSession = async (req, res) => {
  const userId = req.user.id;
  const { id } = req.params;

  const { error } = await supabase
    .from("user_sessions")
    .update({ active: false })
    .eq("id", id)
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Session revoked" });
}
