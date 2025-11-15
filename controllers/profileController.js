import supabase from "../utils/supabaseClient.js";
import sharp from "sharp";

/* -------------------------------------------------------------------------- */
/* 🖼️ UPLOAD AVATAR                                                            */
/* -------------------------------------------------------------------------- */
export const uploadAvatar = async (req, res) => {
  try {
    const userId = req.user.id;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const optimized = await sharp(req.file.buffer)
      .resize(300, 300)
      .png()
      .toBuffer();

    const filePath = `avatars/${userId}-${Date.now()}.png`;

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

    // Save avatar to profile table
    await supabase
      .from("user_profiles")
      .update({ avatar_url: urlData.publicUrl })
      .eq("user_id", userId);

    res.json({
      message: "Avatar updated successfully",
      avatar_url: urlData.publicUrl,
    });
  } catch (err) {
    console.error("UPLOAD ERROR:", err);
    res.status(500).json({ error: "Failed to upload avatar" });
  }
};

/* -------------------------------------------------------------------------- */
/* 📌 GET USER PROFILE (Complete: profile + notifications + security)          */
/* -------------------------------------------------------------------------- */
export const getUserProfile = async (req, res) => {
  const userId = req.user.id;

  const { data: profile, error: pErr } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (pErr) return res.status(400).json({ error: pErr.message });

  const { data: notifications } = await supabase
    .from("user_notifications")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  const { data: security } = await supabase
    .from("user_security")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  res.json({
    profile,
    notifications: notifications || {},
    security: security || {},
  });
};

/* -------------------------------------------------------------------------- */
/* ✏️ UPDATE PROFILE INFO                                                       */
/* -------------------------------------------------------------------------- */
export const updateUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("user_profiles")
      .update({ ...req.body, updated_at: new Date().toISOString() })
      .eq("user_id", userId)
      .select()
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Profile updated", profile: data });
  } catch (err) {
    console.error("SERVER ERROR:", err);
    res.status(500).json({ error: "Unable to update profile" });
  }
};

/* -------------------------------------------------------------------------- */
/* 🔐 CHANGE PASSWORD (Secure, Supabase native)                               */
/* -------------------------------------------------------------------------- */
export const changePassword = async (req, res) => {
  const { new_password } = req.body;

  const userId = req.user.id;

  const { error } = await supabase.auth.updateUser({
    password: new_password,
  });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Password updated successfully" });
};

/* -------------------------------------------------------------------------- */
/* 🎨 UPDATE PREFERENCES (Theme, Language, Timezone)                          */
/* -------------------------------------------------------------------------- */
export const updatePreferences = async (req, res) => {
  const userId = req.user.id;

  const { error } = await supabase
    .from("user_preferences")
    .upsert({ user_id: userId, ...req.body });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Preferences updated" });
};

/* -------------------------------------------------------------------------- */
/* 🔔 NOTIFICATION SETTINGS                                                    */
/* -------------------------------------------------------------------------- */
export const updateNotifications = async (req, res) => {
  const userId = req.user.id;

  const updates = { ...req.body, updated_at: new Date().toISOString() };

  const { error } = await supabase
    .from("user_notifications")
    .upsert({ user_id: userId, ...updates });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Notifications updated" });
};

/* -------------------------------------------------------------------------- */
/* 🛡️ TWO-FACTOR AUTH                                                         */
/* -------------------------------------------------------------------------- */
export const toggleTwoFactor = async (req, res) => {
  const userId = req.user.id;
  const { enabled, method } = req.body;

  const { error } = await supabase
    .from("user_security")
    .upsert({
      user_id: userId,
      two_factor_enabled: enabled,
      two_factor_method: method || "none",
    });

  if (error) return res.status(400).json({ error: error.message });

  res.json({
    message: `Two-Factor Authentication ${enabled ? "enabled" : "disabled"}`,
  });
};

/* -------------------------------------------------------------------------- */
/* 🖥️ SESSIONS LIST                                                            */
/* -------------------------------------------------------------------------- */
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

/* -------------------------------------------------------------------------- */
/* ❌ REVOKE SESSION                                                           */
/* -------------------------------------------------------------------------- */
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
};
