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

    await supabase.from("drm_devices").insert({
      user_id: userId,
      device_id,
      created_at: new Date(),
    });

    return res.json({ message: "Device registered" });
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
    const { book_id, note_id } = req.query;

    const id = book_id || note_id;
    const isNote = !!note_id;

    if (!id)
      return res.json({ can_read: false, reason: "missing_id" });

    // Load DRM settings
    const { data: settings } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)
      .single();

    // Fetch item (book or note)
    let itemRow;

    if (isNote) {
      const { data } = await supabase
        .from("notes")
        .select("id, title, price")
        .eq("id", id)
        .single();

      itemRow = data;
    } else {
      const { data } = await supabase
        .from("ebooks")
        .select("id, title, price")
        .eq("id", id)
        .single();

      itemRow = data;
    }

    // FIXED: correct check
    if (!itemRow) {
      return res.json({
        can_read: false,
        reason: isNote ? "note_not_found" : "book_not_found",
      });
    }

    const isFree = Number(itemRow.price) === 0;

    // Subscription check
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("user_id", userId)
      .eq("status", "active")
      .maybeSingle();

    const subscriptionActive = !!subscription;

    // Individual purchase check
    let individuallyPurchased = false;

    if (isNote) {
      const { data } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", id)
        .maybeSingle();

      individuallyPurchased = !!data;
    } else {
      const { data } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", id)
        .maybeSingle();

      individuallyPurchased = !!data;
    }

    // Final access rule
    const can_read = isFree || subscriptionActive || individuallyPurchased;

    return res.json({
      can_read,
      reason: can_read ? null : "no_valid_access",
      isFree,
      subscriptionActive,
      individuallyPurchased,
      item_type: isNote ? "note" : "book",

      // DRM flags
      copy_protection: settings?.copy_protection ?? false,
      screenshot_prevention: settings?.screenshot_prevention ?? false,
      watermarking: settings?.watermarking ?? false,
      device_limit: settings?.device_limit ?? 3,
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
