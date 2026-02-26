import supabase from "../../utils/pgClient.js";

/* ✅ GET SYSTEM SETTINGS */
export const getSystemSettings = async (req, res) => {
  const { data, error } = await supabase
    .from("system_settings")
    .select("*")
    .single();

  if (error) return res.status(400).json({ error: error.message });
  res.json({ settings: data });
};

/* ✅ UPDATE SYSTEM SETTINGS */
export const updateSystemSettings = async (req, res) => {
  try {
    const { id, ...updates } = req.body;

    if (!id) {
      return res.status(400).json({ error: "Missing settings id" });
    }

    const { data, error } = await supabase
      .from("system_settings")
      .update({ 
        ...updates, 
        updated_at: new Date() 
      })
      .eq("id", id)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ 
      message: "Settings updated successfully",
      settings: data
    });

  } catch (err) {
    console.error("updateSystemSettings error:", err);
    res.status(500).json({ error: "Server error" });
  }
};


/* ✅ GET ALL INTEGRATIONS */
export const getIntegrations = async (req, res) => {
  const { data, error } = await supabase.from("integrations").select("*");
  if (error) return res.status(400).json({ error: error.message });
  res.json({ integrations: data });
};

/* ✅ UPDATE SINGLE INTEGRATION */
export const updateIntegration = async (req, res) => {
  const { id } = req.params;
  const updates = req.body;

  const { data, error } = await supabase
    .from("integrations")
    .update({ ...updates, updated_at: new Date() })
    .eq("id", id)
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Integration updated", integration: data });
};


/* ✅ MAKE BACKUP */
export const createBackup = async (req, res) => {
  const fileUrl = `https://dummyurl.com/backup-${Date.now()}.zip`;

  await supabase.from("system_backups").insert([
    { status: "completed", file_url: fileUrl }
  ]);

  await supabase
    .from("system_settings")
    .update({ last_backup: new Date() });

  res.json({
    message: "Backup created",
    file_url: fileUrl
  });
};

/* ✅ CHANGE ADMIN PASSWORD */
import pool from "../../utils/db.js";
import bcrypt from "bcrypt";

export const changeAdminPassword = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { current_password, new_password } = req.body;

    if (!current_password || !new_password) {
      return res.status(400).json({ error: "Current and new password are required" });
    }

    // 1. Fetch current admin hashed password
    const { rows } = await pool.query(
      "SELECT password_hash FROM profiles WHERE id = $1 AND role IN ('super_admin', 'org_admin')",
      [adminId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Admin profile not found" });
    }

    const { password_hash } = rows[0];

    // 2. Verify current password
    const isValid = await bcrypt.compare(current_password, password_hash);
    if (!isValid) {
      return res.status(401).json({ error: "Incorrect current password" });
    }

    // 3. Hash new password and update
    const newHash = await bcrypt.hash(new_password, 12);

    await pool.query(
      "UPDATE profiles SET password_hash = $1 WHERE id = $2",
      [newHash, adminId]
    );

    return res.json({ message: "Admin password updated successfully" });
  } catch (error) {
    console.error("changeAdminPassword error:", error);
    return res.status(500).json({ error: "Failed to change admin password" });
  }
};
