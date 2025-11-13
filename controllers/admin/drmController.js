import supabase from "../../utils/supabaseClient.js";

/* ---------------------------------------------
   ✅ GET DRM SETTINGS
---------------------------------------------- */
export const getDRMSettings = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_settings")
      .select("*")
      .single();

    if (error) return res.status(400).json({ error: error.message });
    res.json(data);

  } catch (err) {
    console.error("getDRMSettings error:", err);
    res.status(500).json({ error: "Server error fetching DRM settings" });
  }
};

/* ---------------------------------------------
   ✅ UPDATE DRM SETTINGS
---------------------------------------------- */
export const updateDRMSettings = async (req, res) => {
  try {
    const updates = req.body;

    const { data, error } = await supabase
      .from("drm_settings")
      .update({ ...updates, updated_at: new Date() })
      .eq("id", updates.id)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "DRM settings updated", data });

  } catch (err) {
    console.error("updateDRMSettings error:", err);
    res.status(500).json({ error: "Server error updating DRM settings" });
  }
};

/* ---------------------------------------------
   ✅ GET ACCESS LOGS (Recent logs list)
---------------------------------------------- */
export const getAccessLogs = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_access_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);

    if (error) return res.status(400).json({ error: error.message });

    res.json(data);

  } catch (err) {
    console.error("getAccessLogs error:", err);
    res.status(500).json({ error: "Server error fetching access logs" });
  }
};

/* ---------------------------------------------
   ✅ ADD WATERMARK (Placeholder)
---------------------------------------------- */
export const addWatermark = async (req, res) => {
  try {
    console.log("BODY:", req.body);  // ✅ Debug
    const { book_id } = req.body;

    if (!book_id) {
      return res.status(400).json({ error: "book_id is required" });
    }

    return res.json({ message: `Watermark added to book ${book_id}` });

  } catch (err) {
    console.error("addWatermark fatal error:", err);
    res.status(500).json({ error: err.message });
  }
};


/* ---------------------------------------------
   ✅ GET ACTIVE LICENSES (Subscriptions)
---------------------------------------------- */
export const getActiveLicenses = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("subscriptions")
      .select("user_id, plan, status, end_date")
      .eq("status", "active");

    if (error) return res.status(400).json({ error: error.message });

    res.json(data);

  } catch (err) {
    console.error("getActiveLicenses error:", err);
    res.status(500).json({ error: "Server error loading licenses" });
  }
};

/* ---------------------------------------------
   ✅ REVOKE USER ACCESS
---------------------------------------------- */
export const revokeAccess = async (req, res) => {
  try {
    const { user_id } = req.body;

    const { error } = await supabase
      .from("subscriptions")
      .update({ status: "revoked" })
      .eq("user_id", user_id);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "User access revoked" });

  } catch (err) {
    console.error("revokeAccess error:", err);
    res.status(500).json({ error: "Server error revoking access" });
  }
};

/* ---------------------------------------------
   ✅ DOWNLOAD DRM ACCESS REPORT (CSV)
---------------------------------------------- */
export const downloadAccessReport = async (req, res) => {
  try {
    const { data } = await supabase
      .from("drm_access_logs")
      .select("*");

    const csv = data
      .map(
        row =>
          `${row.user_name},${row.book_title},${row.action},${row.device},${row.ip_address},${row.created_at}`
      )
      .join("\n");

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      "attachment; filename=access_report.csv"
    );
    res.send(csv);

  } catch (err) {
    console.error("downloadAccessReport error:", err);
    res.status(500).json({ error: "Server error generating report" });
  }
};
