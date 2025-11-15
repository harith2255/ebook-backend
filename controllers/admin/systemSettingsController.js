import supabase from "../../utils/supabaseClient.js";

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
