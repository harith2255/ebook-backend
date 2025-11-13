import supabase from "../utils/supabaseClient.js";

/* ✅ Get notifications for logged-in user */
export const getUserNotifications = async (req, res) => {
  try {
    const user_id = req.user.id;

    const { data, error } = await supabase
      .from("user_notifications")
      .select("*")
      .eq("user_id", user_id)
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ notifications: data });
  } catch (err) {
    console.error("getUserNotifications error:", err);
    res.status(500).json({ error: "Server error getting notifications" });
  }
};

/* ✅ Mark as read */
export const markNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from("user_notifications")
      .update({ is_read: true })
      .eq("id", id);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Marked as read" });
  } catch (err) {
    console.error("markNotificationRead error:", err);
    res.status(500).json({ error: "Server error marking notification read" });
  }
};
