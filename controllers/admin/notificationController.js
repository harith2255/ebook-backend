// controllers/admin/notificationController.js
import { supabaseAdmin } from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   GET RECIPIENTS
------------------------------------------------------- */
async function getRecipients(type, customList) {
  const { data: authData } = await supabaseAdmin.auth.admin.listUsers();
  const users = authData?.users || [];

  const userMap = new Map(users.map(u => [u.id, u.email]));

  if (type === "all") {
    return users.map(u => ({ id: u.id, email: u.email }));
  }

  if (["active", "inactive", "trial"].includes(type)) {
    let q = supabaseAdmin.from("profiles").select("id");

    if (type === "active") q.eq("status", "Active");
    if (type === "inactive") q.eq("status", "Inactive");
    if (type === "trial") q.eq("plan", "Trial");

    const { data } = await q;

    return (data || [])
      .map(p => ({ id: p.id, email: userMap.get(p.id) }))
      .filter(u => u.email);
  }

  if (type === "custom") {
    return (customList || []).map(email => ({ id: null, email }));
  }

  return [];
}

/* -------------------------------------------------------
   SEND NOTIFICATION (DEV mode)
------------------------------------------------------- */
export const sendNotification = async (req, res) => {
  try {
    const { recipient_type, notification_type, subject, message, custom_list } = req.body;

    const recipients = await getRecipients(recipient_type, custom_list);
    console.log("📦 DEV MODE - Recipients:", recipients);

    let delivered = 0;

    /* ---------------------------------------------------
       1️⃣ EMAIL SENDING — DISABLED IN DEV MODE
       (No SMTP → no error, just skip)
    --------------------------------------------------- */
    if (notification_type === "email" || notification_type === "both") {
      console.log("📩 DEV MODE: Skipping email sending.");
      delivered = recipients.length;  // simulate "delivered"
    }

    /* ---------------------------------------------------
       2️⃣ WEBSITE NOTIFICATIONS (stored in DB)
    --------------------------------------------------- */
    if (notification_type === "website" || notification_type === "both") {
      for (const user of recipients) {
        if (!user.id) continue;

        await supabaseAdmin.from("user_notifications").insert({
          user_id: user.id,
          title: subject,
          message,
          is_read: false
        });

        delivered++;
      }
    }

    /* ---------------------------------------------------
       3️⃣ LOG NOTIFICATION
    --------------------------------------------------- */
    await supabaseAdmin.from("notification_logs").insert({
      subject,
      message,
      recipient_type,
      notification_type,
      delivered_count: delivered,
      custom_list
    });

    return res.json({
      message: "DEV MODE: Notification logged",
      delivered,
      recipients
    });

  } catch (err) {
    console.error("sendNotification error:", err);
    res.status(500).json({ error: "Error sending notification (dev mode)" });
  }
};

/* -------------------------------------------------------
   SAVE DRAFT
------------------------------------------------------- */
export const saveDraft = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("notification_drafts")
      .insert(req.body)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Draft saved", draft: data });
  } catch (err) {
    console.error("saveDraft error:", err);
    res.status(500).json({ error: "Error saving draft" });
  }
};

/* -------------------------------------------------------
   GET ALL SENT NOTIFICATIONS
------------------------------------------------------- */
export const getNotifications = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("notification_logs")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ notifications: data });

  } catch (err) {
    console.error("getNotifications error:", err);
    res.status(500).json({ error: "Error loading notifications" });
  }
};
