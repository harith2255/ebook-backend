// drmCheck.js (updated)
import supabase from "../utils/supabaseClient.js";

export const drmCheck = async (req, res, next) => {
  try {
    const userId = req.user?.id; // from auth middleware
    const deviceInfo = req.headers["user-agent"];
    const ip = req.ip;
    const noteId = Number(req.params.id || req.body.noteId || req.params.noteId);

    // 1. Load DRM settings
    const { data: drm } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)
      .single();

    // 2. Check active subscription
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("user_id", userId)
      .single();

    // 3. Check per-note purchase (if this is a note route)
    let hasPurchasedNote = false;
    if (noteId) {
      const { data: notePurchase } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", noteId)
        .maybeSingle();
      hasPurchasedNote = !!notePurchase;
    }

    // If neither subscription active nor purchased this note => deny
    const subscriptionActive = sub && sub.status === "active";

    if (!subscriptionActive && !hasPurchasedNote) {
      return res.status(403).json({ error: "Access revoked, expired, or note not purchased" });
    }

    // 4. Check device limit (only applies if subscriptionActive or purchasedNote — still keep device limit)
    const { data: logs } = await supabase
      .from("drm_access_logs")
      .select("device_info")
      .eq("user_id", userId);

    const uniqueDevices = [...new Set((logs || []).map(l => l.device_info))];

    if (drm && drm.device_limit && uniqueDevices.length >= drm.device_limit && !uniqueDevices.includes(deviceInfo)) {
      return res.status(403).json({ error: "Device limit reached" });
    }

    // 5. Log access
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: req.user?.name || req.user?.email || "Unknown",
      book_id: null,
      book_title: null,
      action: "view",
      device_info: deviceInfo,
      ip_address: ip,
      created_at: new Date(),
      note_id: noteId || null,
      note_title: req.noteTitle || null
    });

    // Attach DRM settings for handlers
    req.drm = drm;

    next();
  } catch (err) {
    console.error("drmCheck error:", err);
    return res.status(500).json({ error: "DRM check failed" });
  }
};
