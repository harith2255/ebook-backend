// controllers/admin/notificationController.js
import { supabaseAdmin } from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   1️⃣ FETCH ALL USERS (with pagination)
------------------------------------------------------- */
async function fetchAllUsers() {
  let page = 1;
  const perPage = 100;
  let all = [];

  while (true) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({
      page,
      perPage,
    });

    if (error) {
      console.error("❌ listUsers pagination error:", error);
      break;
    }

    all = [...all, ...data.users];

    if (data.users.length < perPage) break;
    page++;
  }

  return all;
}

/* -------------------------------------------------------
   2️⃣ GET RECIPIENTS
------------------------------------------------------- */
async function getRecipients(type, customList = []) {
  const users = await fetchAllUsers();

  if (!users.length) return [];

  switch (type) {
    case "all":
      return users;

    case "active":
      return users.filter(u => u.user_metadata?.status === "active");

    case "inactive":
      return users.filter(u => u.user_metadata?.status === "inactive");

    case "trial":
      return users.filter(u => u.user_metadata?.plan === "trial");

    case "custom":
      return users.filter(u => customList.includes(u.email));

    default:
      return [];
  }
}

/* -------------------------------------------------------
   3️⃣ SEND NOTIFICATION
------------------------------------------------------- */
export const sendNotification = async (req, res) => {
  try {
    const { recipient_type, notification_type, subject, message, custom_list } =
      req.body;

    const recipients = await getRecipients(recipient_type, custom_list);
    console.log("📦 Sending to recipients:", recipients.length);

    if (!recipients.length) {
      return res.json({ message: "No recipients match your selection." });
    }

    let delivered = 0;

    /* -----------------------------
       📧 EMAIL (DEV MODE SKIPPED)
    ------------------------------- */
    if (notification_type === "email" || notification_type === "both") {
      console.log("📨 Email sending skipped (dev mode)");
      delivered += recipients.length;
    }

    /* -----------------------------
       🌐 WEBSITE NOTIFICATIONS
    ------------------------------- */
    if (notification_type === "website" || notification_type === "both") {
      for (const user of recipients) {
        await supabaseAdmin.from("user_notifications").insert({
          user_id: user.id,
          title: subject,
          message,
          link: "/notifications",
          is_read: false,
        });
      }
      delivered += recipients.length;
    }

    /* -----------------------------
       📝 LOG ACTION (ONE ENTRY ONLY)
    ------------------------------- */
    await supabaseAdmin.from("notification_logs").insert({
      id: crypto.randomUUID(),
      subject,
      message,
      recipient_type,
      delivered_count: delivered,
      created_at: new Date(),
    });

    return res.json({
      message: "Notification sent successfully",
      delivered,
      recipients: recipients.map(u => ({
        id: u.id,
        email: u.email,
      })),
    });

  } catch (err) {
    console.error("❌ sendNotification error:", err);
    return res.status(500).json({ error: "Error sending notification" });
  }
};

/* -------------------------------------------------------
   4️⃣ SAVE DRAFT
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
    console.error("❌ saveDraft error:", err);
    res.status(500).json({ error: "Error saving draft" });
  }
};

/* -------------------------------------------------------
   5️⃣ GET ALL SENT NOTIFICATIONS (ADMIN VIEW)
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
    console.error("❌ getNotifications error:", err);
    res.status(500).json({ error: "Error loading notifications" });
  }
};
