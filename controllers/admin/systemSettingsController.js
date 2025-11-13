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

/* ✅ GET ROLES */
export const getRoles = async (req, res) => {
  try {
    // get all roles
    const { data: roles, error } = await supabase
      .from("roles")
      .select("id, name, permissions");

    if (error) return res.status(400).json({ error: error.message });

    // count users per role (assuming profiles.role exists)
    const { data: profiles } = await supabase
      .from("profiles")
      .select("role");

    const roleCounts = {};
    profiles?.forEach(p => {
      if (!roleCounts[p.role]) roleCounts[p.role] = 0;
      roleCounts[p.role]++;
    });

    // attach users count for UI display
    const finalOutput = roles.map(r => ({
      id: r.id,
      name: r.name,
      permissions: r.permissions,
      users: roleCounts[r.name] || 0
    }));

    res.json({ roles: finalOutput });

  } catch (err) {
    console.error("getRoles error:", err);
    res.status(500).json({ error: "Failed to load roles" });
  }
};


/* ✅ CREATE NEW ROLE */
export const createRole = async (req, res) => {
  const { name, permissions } = req.body;

  // ✅ check if role already exists
  const { data: existingRole } = await supabase
    .from("roles")
    .select("id")
    .eq("name", name)
    .single();

  if (existingRole) {
    return res.status(400).json({
      error: "Role already exists. Choose a different name."
    });
  }

  // ✅ insert new role
  const { data, error } = await supabase
    .from("roles")
    .insert([{ name, permissions }])
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Role added", role: data });
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
