import supabase from "../../utils/supabaseClient.js";

/* ======================================================
   GET DRM SETTINGS
====================================================== */
export const getDRMSettings = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_settings")
      .select("id, copy_protection, watermarking, device_limit, screenshot_prevention")

      .eq("id", 1)
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ settings: data });
  } catch (err) {
    console.error("getDRMSettings error:", err);
    return res.status(500).json({ error: "Failed to fetch settings" });
  }
};

/* ======================================================
   UPDATE DRM SETTINGS
====================================================== */
export const updateDRMSettings = async (req, res) => {
  try {
    const { settings } = req.body;
    if (!settings) return res.status(400).json({ error: "Missing settings" });

    const { data, error } = await supabase
      .from("drm_settings")
      .update({
        ...settings,
        updated_at: new Date(),
      })
      .eq("id", 1)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ message: "Settings updated", settings: data });
  } catch (err) {
    console.error("updateDRMSettings error:", err);
    return res.status(500).json({ error: "Failed to update settings" });
  }
};



/* ======================================================
   GET ACCESS LOGS
====================================================== */
export const getAccessLogs = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_access_logs")
      .select("user_id, user_name, action, book_title, device_info, ip_address, created_at")
      .order("created_at", { ascending: false })
      .limit(100);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ logs: data });
  } catch (err) {
    res.status(500).json({ error: "Failed to load logs" });
  }
};

/* ======================================================
   ADD WATERMARK (QUEUE JOB)
====================================================== */
export const addWatermark = async (req, res) => {
  try {
    const { book_id } = req.body;

    if (!book_id) return res.status(400).json({ error: "book_id required" });

    await supabase.from("watermark_jobs").insert({
      book_id,
      status: "queued",
      created_at: new Date(),
    });

    return res.json({ message: "Watermark job queued" });
  } catch (err) {
    return res.status(500).json({ error: "Failed to queue job" });
  }
};

/* ======================================================
   GET ACTIVE SUBSCRIPTIONS
====================================================== */
export const getActiveLicenses = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("status", "active");

    if (error) return res.status(400).json({ error: error.message });

    res.json({ licenses: data });
  } catch (err) {
    res.status(500).json({ error: "Failed to load licenses" });
  }
};

/* ======================================================
   REVOKE USER ACCESS
====================================================== */
export const revokeAccess = async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) return res.status(400).json({ error: "userId required" });

    await supabase
      .from("subscriptions")
      .update({ status: "revoked" })
      .eq("user_id", userId);

    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      action: "revoked",
      created_at: new Date(),
    });

    return res.json({ message: "User access revoked" });
  } catch (err) {
    return res.status(500).json({ error: "Failed to revoke access" });
  }
};

/* ======================================================
   EXPORT CSV REPORT
====================================================== */
export const downloadAccessReport = async (req, res) => {
  try {
    const { data } = await supabase.from("drm_access_logs").select("*");

    const csv = [
      "user_id,book_title,action,device,ip,created_at",
      ...data.map((r) =>
        `${r.user_id},${r.book_title ?? ""},${r.action},${r.device_info},${r.ip},${r.created_at}`
      ),
    ].join("\n");

    res.header("Content-Type", "text/csv");
    res.header("Content-Disposition", "attachment; filename=drm_report.csv");
    return res.send(csv);
  } catch (err) {
    return res.status(500).json({ error: "Failed to export report" });
  }
};
