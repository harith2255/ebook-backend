export const drmCheck = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "unauthorized" });
    }

    const deviceInfo = req.headers["x-device-id"];
    if (!deviceInfo) {
      return res.status(400).json({ error: "missing_device_id" });
    }

    const bookId = req.query.book_id || req.body.book_id || null;
    const noteId = req.query.note_id || req.body.note_id || null;

    // ✅ EXACTLY ONE
    if (!!bookId === !!noteId) {
      return res.status(400).json({
        error: "invalid_item_identifier",
      });
    }

    /* ================= DRM SETTINGS ================= */
    const { data: drm } = await supabase
      .from("drm_settings")
      .select("*")
      .eq("id", 1)
      .single();

    /* ================= SUBSCRIPTION ================= */
    let subscriptionActive = false;

    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("status")
      .eq("user_id", userId)
      .maybeSingle();

    if (subscription?.status === "active") {
      const { data: profile } = await supabase
        .from("profiles")
        .select("account_status")
        .eq("id", userId)
        .single();

      if (profile?.account_status !== "suspended") {
        subscriptionActive = true;
      }
    }

    /* ================= PURCHASE ================= */
    let individuallyPurchased = false;

    if (bookId) {
      const { data } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", bookId)
        .maybeSingle();

      individuallyPurchased = !!data;
    }

    if (noteId) {
      const { data } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", noteId)
        .maybeSingle();

      individuallyPurchased = !!data;
    }

    if (!subscriptionActive && !individuallyPurchased) {
      return res.status(403).json({
        error: "no_valid_access",
      });
    }

    /* ================= DEVICE LIMIT ================= */
    const { data: devices } = await supabase
      .from("drm_devices")
      .select("device_id")
      .eq("user_id", userId);

    const knownDevices = devices?.map(d => d.device_id) || [];

    if (
      drm?.device_limit &&
      knownDevices.length >= drm.device_limit &&
      !knownDevices.includes(deviceInfo)
    ) {
      return res.status(403).json({
        error: "device_limit_exceeded",
      });
    }

    /* ================= REGISTER DEVICE ================= */
    await supabase.from("drm_devices").upsert(
      {
        user_id: userId,
        device_id: deviceInfo,
        created_at: new Date(),
      },
      { onConflict: "user_id,device_id" }
    );

    req.drm = drm;
    next();
  } catch (err) {
    console.error("❌ drmCheck error:", err);
    return res.status(500).json({ error: "drm_failed" });
  }
};
