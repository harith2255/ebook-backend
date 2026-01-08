import supabase from "../utils/supabaseClient.js";
export function getDeviceId() {
  let deviceId = localStorage.getItem("device_id");

  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem("device_id", deviceId);
  }

  return deviceId;
}



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
const device_id = req.headers["x-device-id"] ?? null;



if (!!book_id === !!note_id) {
  return res.json({
    can_read: false,
    reason: "invalid_item_identifier", // must send exactly ONE
  });
}

const isNote = !!note_id;
const id = isNote ? note_id : book_id;


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

if (isFree) {
  return res.json({
    can_read: true,
    reason: null,
    isFree: true,
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
}

let can_read = subscriptionActive || individuallyPurchased;


    // Device limit check (only if paid content)
    if (!isFree) {
    let can_read = isFree || subscriptionActive || individuallyPurchased;

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
    }
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
