import supabase from "../utils/supabaseClient.js";

/* ======================================================
   REGISTER DEVICE
====================================================== */
export const registerDevice = async (req, res) => {
  try {
    const userId = req.user.id;
    const { device_id } = req.body;

    if (!device_id)
      return res.status(400).json({ error: "device_id required" });

    const { data, error } = await supabase
      .from("drm_devices")
      .upsert(
        {
          user_id: userId,
          device_id,
          created_at: new Date(),
        },
        { onConflict: "user_id,device_id" } // <-- tell Supabase which fields are unique
      );

    if (error) {
      console.error("upsert error:", error);
      return res.status(500).json({ error: "Failed to register device" });
    }

    return res.json({ message: "Device registered", data });
  } catch (err) {
    console.error("registerDevice error:", err);
    return res.status(500).json({ error: "Failed to register device" });
  }
};


/* ======================================================
   DRM CHECK ACCESS — Books + Notes
====================================================== */
/* ======================================================
   DRM CHECK ACCESS — Books + Notes
====================================================== */
export const checkDRMAccess = async (req, res) => {
  try {
    const userId = req.user.id;
    const { book_id, note_id, device_id } = req.query;

    const id = book_id || note_id;
    const isNote = !!note_id;

    if (!device_id)
      return res.json({ can_read: false, reason: "missing_device_id" });

    if (!id)
      return res.json({ can_read: false, reason: "missing_id" });

    // DRM settings
    const { data: settings } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)
      .single();

    if (!settings)
      return res.json({ can_read: false, reason: "settings_missing" });

    // Fetch book/note
    const table = isNote ? "notes" : "ebooks";
    const { data: itemRow } = await supabase
      .from(table)
      .select("id, title, price")
      .eq("id", id)
      .maybeSingle();

    if (!itemRow)
      return res.json({ can_read: false, reason: "item_not_found" });

    const isFree = Number(itemRow.price) === 0;

    // Subscription check
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("id")
      .eq("user_id", userId)
      .eq("status", "active")
      .maybeSingle();

    const subscriptionActive = !!subscription;

    // Individual purchase check
    const purchaseTable = isNote ? "notes_purchase" : "book_sales";
    const { data: purchased } = await supabase
      .from(purchaseTable)
      .select("id")
      .eq("user_id", userId)
      .eq(isNote ? "note_id" : "book_id", id)
      .maybeSingle();

    const individuallyPurchased = !!purchased;

    let can_read = isFree || subscriptionActive || individuallyPurchased;

    // Device limit check (only if paid content)
    if (!isFree) {
      const { data: devices } = await supabase
        .from("drm_devices")
        .select("device_id")
        .eq("user_id", userId);

      const alreadyRegistered = devices.some(d => d.device_id === device_id);

      if (devices.length >= settings.device_limit && !alreadyRegistered) {
        can_read = false;
        return res.json({
          can_read,
          reason: "device_limit_exceeded",
          allowed_devices: devices.length,
          device_limit: settings.device_limit,
        });
      }
    }

    return res.json({
      can_read,
      reason: can_read ? null : "no_valid_access",
      isFree,
      subscriptionActive,
      individuallyPurchased,
      item_type: isNote ? "note" : "book",
      copy_protection: settings.copy_protection,
      screenshot_prevention: settings.screenshot_prevention,
      watermarking: settings.watermarking,
      device_limit: settings.device_limit,
      watermark_text: settings.watermarking
        ? (req.user.email || req.user.id)
        : null,
    });

  } catch (err) {
    console.error("checkDRMAccess error:", err);
    return res.json({
      can_read: false,
      reason: "server_error",
    });
  }
};

export const logAccessEvent = async (req, res) => {
  try {
    const userId = req.user.id;
    const { book_id, page, device_id } = req.body;

    if (!book_id)
      return res.status(400).json({ error: "book_id required" });

    // Get user name
    const { data: user } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", userId)
      .maybeSingle();

    // Get book name
    const { data: book } = await supabase
      .from("ebooks")
      .select("title")
      .eq("id", book_id)
      .maybeSingle();

    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: user?.full_name ?? "Unknown",
      book_id,
      book_title: book?.title ?? "Unknown Book",
      action: "read",
      device_info: device_id ?? req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
    });

    res.json({ success: true });
  } catch (err) {
    console.error("logAccessEvent error:", err);
    res.status(500).json({ error: "Failed to log event" });
  }
};
