import supabase from "../utils/pgClient.js";



// ✅ GET notifications
export const getUserNotifications = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: "Unauthorized. No user ID." });
    }

    const user_id = req.user.id;

    const { data, error } = await supabase
      .from("user_notifications")
      .select("*")
      .eq("user_id", user_id)
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    // frontend expects -> { notifications: [] }
    return res.json({ notifications: data });
  } catch (err) {
    console.error("getUserNotifications error:", err);
    return res.status(500).json({ error: "Server error getting notifications" });
  }
};

// ✅ MARK ONE AS READ
export const markNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from("user_notifications")
      .update({ is_read: true })
      .eq("id", id);

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ message: "Marked as read" });
  } catch (err) {
    console.error("markNotificationRead error:", err);
    return res.status(500).json({ error: "Server error marking read" });
  }
};

// ✅ MARK ALL AS READ
export const markAllNotificationsRead = async (req, res) => {
  try {
    const user_id = req.user.id;

    const { error } = await supabase
      .from("user_notifications")
      .update({ is_read: true })
      .eq("user_id", user_id);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "All notifications marked as read" });

  } catch (err) {
    console.error("markAllNotificationsRead error:", err);
    res.status(500).json({ error: "Server error updating notifications" });
  }
};
