import supabase from "../utils/supabaseClient.js";
import sharp from "sharp";

/* ----------------------------------------------------------------------------
   1. UPLOAD AVATAR  (writes to profiles.avatar_url)
---------------------------------------------------------------------------- */
export const uploadAvatar = async (req, res) => {
  try {
    const userId = req.user.id;

    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    // optimize image
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

    // update profile
    await supabase
      .from("profiles")
      .update({ avatar_url: urlData.publicUrl })
      .eq("id", userId);

    res.json({
      message: "Avatar updated successfully",
      avatar_url: urlData.publicUrl,
    });
  } catch (err) {
    console.error("UPLOAD ERROR:", err);
    res.status(500).json({ error: "Failed to upload avatar" });
  }
};

/* ----------------------------------------------------------------------------
   2. GET USER PROFILE  (profiles + notifications)
---------------------------------------------------------------------------- */
export const getUserProfile = async (req, res) => {
  const userId = req.user.id;

  const { data: profile, error: pErr } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  if (pErr) return res.status(400).json({ error: pErr.message });

  // user notifications
  const { data: notifications } = await supabase
    .from("user_notifications")
    .select("*")
    .eq("user_id", userId);

  res.json({
    profile,
    notifications
  });
};

/* ----------------------------------------------------------------------------
   3. UPDATE PROFILE
---------------------------------------------------------------------------- */
export const updateUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("profiles")
      .update({ ...req.body })
      .eq("id", userId)
      .select()
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Profile updated", profile: data });
  } catch (err) {
    console.error("SERVER ERROR:", err);
    res.status(500).json({ error: "Unable to update profile" });
  }
};

/* ----------------------------------------------------------------------------
   4. CHANGE PASSWORD (Supabase native)
---------------------------------------------------------------------------- */
export const changePassword = async (req, res) => {
  const { new_password } = req.body;

  const { error } = await supabase.auth.updateUser({
    password: new_password,
  });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Password updated successfully" });
};

/* ----------------------------------------------------------------------------
   5. UPDATE NOTIFICATION SETTINGS 
   (Your DB does NOT have this table, so we store into profiles)
---------------------------------------------------------------------------- */
export const updateNotifications = async (req, res) => {
  const userId = req.user.id;

  const { email_notifications, push_notifications } = req.body;

  const { error } = await supabase
    .from("profiles")
    .update({
      email_notifications,
      push_notifications
    })
    .eq("id", userId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Notification settings updated" });
};

/* ----------------------------------------------------------------------------
   6. SESSIONS (Your DB has user_sessions table)
---------------------------------------------------------------------------- */
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
      updated_at: new Date().toISOString()
    });

  if (error) return res.status(400).json({ error: error.message });

  res.json({
    message: `Two-Factor Authentication ${enabled ? "enabled" : "disabled"}`
  });
};
/* -------------------------------------------------------------------------- */
/* 🎨 UPDATE PREFERENCES (Theme, Language, Timezone)                          */
/* -------------------------------------------------------------------------- */
export const updatePreferences = async (req, res) => {
  const userId = req.user.id;

  const { error } = await supabase
    .from("user_preferences")
    .upsert({
      user_id: userId,
      ...req.body,
      updated_at: new Date().toISOString()
    });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Preferences updated" });
};
