// drmCheck.js (FINAL VERSION)
import supabase from "../utils/supabaseClient.js";

export const drmCheck = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    const deviceInfo = req.headers["user-agent"];
    const ip = req.ip;

   const bookId =
  req.params.bookId ||
  req.params.id ||
  req.body.book_id ||
  req.body.bookId;

const noteId =
  req.params.noteId ||
  req.params.id ||
  req.body.note_id ||
  req.body.noteId;


    /* ======================================================
       1) LOAD DRM SETTINGS
    ====================================================== */
    const { data: drm } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)
      .single();

    /* ======================================================
       2) CHECK SUBSCRIPTION
    ====================================================== */
// 2) CHECK SUBSCRIPTION — only if NOT suspended
let subscriptionActive = false;

if (subscription && subscription.status === "active") {
  const { data: profile } = await supabase
    .from("profiles")
    .select("account_status")
    .eq("id", userId)
    .single();

  if (profile?.account_status !== "suspended") {
    subscriptionActive = true;
  }
}


    /* ======================================================
       3) CHECK BOOK PURCHASE (IMPORTANT!)
    ====================================================== */
    let hasPurchasedBook = false;

    if (bookId) {
      const { data: bookPurchase } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", bookId)
        .maybeSingle();

      hasPurchasedBook = !!bookPurchase;
    }

    /* ======================================================
       4) CHECK NOTE PURCHASE
    ====================================================== */
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

    /* ======================================================
       5) ACCESS RULE
          ALLOW if:
          - user purchased THIS book, OR
          - user purchased THIS note, OR
          - user has active subscription
    ====================================================== */
    if (!hasPurchasedBook && !hasPurchasedNote && !subscriptionActive) {
      return res.status(403).json({
        error: "Access denied. Purchase or subscription required.",
      });
    }

    /* ======================================================
       6) DEVICE LIMIT CHECK
    ====================================================== */
    const { data: logs } = await supabase
      .from("drm_access_logs")
      .select("device_info")
      .eq("user_id", userId);

    const uniqueDevices = [...new Set((logs || []).map((l) => l.device_info))];

    if (
      drm?.device_limit &&
      uniqueDevices.length >= drm.device_limit &&
      !uniqueDevices.includes(deviceInfo)
    ) {
      return res.status(403).json({ error: "Device limit reached" });
    }

    /* ======================================================
       7) LOG ACCESS
    ====================================================== */
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: req.user?.email || "Unknown",
      book_id: bookId || null,
      note_id: noteId || null,
      action: "view",
      device_info: deviceInfo,
      ip_address: ip,
      created_at: new Date(),
    });

    

    // Pass DRM settings to handlers
    req.drm = drm;

    next();
  } catch (err) {
    console.error("drmCheck error:", err);
    return res.status(500).json({ error: "DRM check failed" });
  }
};
