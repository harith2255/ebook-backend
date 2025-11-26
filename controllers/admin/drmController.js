import supabase from "../../utils/supabaseClient.js";

/* ======================================================
   ✅ GET DRM SETTINGS (ONE ROW)
====================================================== */
export const getDRMSettings = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)      // one settings record
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({
      settings: {
        copy_protection: data.copy_protection,
        watermarking: data.watermarking,
        device_limit: data.device_limit,
        screenshot_prevention: data.screenshot_prevention,
      },
    });
  } catch (err) {
    console.error("getDRMSettings error:", err);
    return res.status(500).json({ error: "Server error fetching DRM settings" });
  }
};



/* ======================================================
   ✅ UPDATE DRM SETTINGS
====================================================== */
export const updateDRMSettings = async (req, res) => {
  try {
    const { settings } = req.body;

    if (!settings)
      return res.status(400).json({ error: "Missing settings payload" });

    const { data, error } = await supabase
      .from("drm_settings")
      .update({
        copy_protection: settings.copy_protection,
        watermarking: settings.watermarking,
        device_limit: settings.device_limit,
        screenshot_prevention: settings.screenshot_prevention,
        updated_at: new Date(),
      })
      .eq("id", 1)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({
      message: "DRM settings updated successfully",
      settings: data,
    });
  } catch (err) {
    console.error("updateDRMSettings error:", err);
    return res.status(500).json({ error: "Failed to update DRM settings" });
  }
};



/* ======================================================
   ✅ GET ACCESS LOGS (Latest 50)
====================================================== */
export const getAccessLogs = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_access_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);

    if (error) {
      console.error("getAccessLogs error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.json({ logs: data });
  } catch (err) {
    console.error("getAccessLogs fatal error:", err);
    return res.status(500).json({ error: "Failed to load access logs" });
  }
};



/* ======================================================
   ✅ ADD WATERMARK (Queue job)
====================================================== */
export const addWatermark = async (req, res) => {
  try {
    const { book_id } = req.body;

    if (!book_id)
      return res.status(400).json({ error: "book_id is required" });

    await supabase.from("watermark_jobs").insert({
      book_id,
      status: "queued",
      created_at: new Date(),
    });

    return res.json({
      message: `Watermark job queued for book ${book_id}`,
    });
  } catch (err) {
    console.error("addWatermark error:", err);
    return res.status(500).json({ error: "Failed to queue watermark job" });
  }
};



/* ======================================================
   ✅ GET ACTIVE LICENSES (Subscriptions)
====================================================== */
export const getActiveLicenses = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("subscriptions")
      .select("user_id, plan, status, end_date")
      .eq("status", "active");

    if (error) {
      console.error("getActiveLicenses error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.json({ licenses: data });
  } catch (err) {
    console.error("getActiveLicenses fatal error:", err);
    return res.status(500).json({ error: "Failed to load active licenses" });
  }
};



/* ======================================================
   ✅ REVOKE USER ACCESS
   Logs into drm_access_logs
====================================================== */
export const revokeAccess = async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId)
      return res.status(400).json({ error: "userId is required" });

    // Update subscription
    const { error } = await supabase
      .from("subscriptions")
      .update({ status: "revoked" })
      .eq("user_id", userId);

    if (error) {
      console.error("revokeAccess error:", error);
      return res.status(400).json({ error: error.message });
    }

    // Log revoke
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: "Admin Panel",
      book_id: null,
      book_title: null,
      action: "revoke",
      device_info: "admin_panel",
      ip_address: req.ip,
      created_at: new Date(),
    });

    return res.json({ message: "User access revoked successfully" });
  } catch (err) {
    console.error("revokeAccess fatal error:", err);
    return res.status(500).json({ error: "Server error revoking user access" });
  }
};



/* ======================================================
   ✅ DOWNLOAD ACCESS LOG REPORT (CSV)
====================================================== */
export const downloadAccessReport = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drm_access_logs")
      .select("*");

    if (error) return res.status(400).json({ error: error.message });

    const csvRows = [
      "user_name,book_title,action,device_info,ip_address,created_at",
      ...data.map((r) =>
        `${r.user_name || ""},${r.book_title || ""},${r.action},${r.device_info},${r.ip_address},${r.created_at}`
      ),
    ].join("\n");

    res.setHeader("Content-Type", "text/csv");
    res.setHeader("Content-Disposition", "attachment; filename=drm_report.csv");

    return res.send(csvRows);
  } catch (err) {
    console.error("downloadAccessReport error:", err);
    return res.status(500).json({ error: "Failed to generate report" });
  }
};
