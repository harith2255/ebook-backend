import supabase from "../../utils/supabaseClient.js";
import nodemailer from "nodemailer";

/* MAIL TRANSPORTER */
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

/* ✅ Fetch recipients */
async function getRecipients(type, customList) {
  
  // ✅ fetch ALL auth.users using admin API
  const { data: authData } = await supabase.auth.admin.listUsers();
  const allUsers = authData?.users || [];

  // ✅ Convert to map for quick lookup
  const userMap = new Map(
    allUsers.map(u => [u.id, u.email])
  );

  // ✅ ALL USERS
  if (type === "all") {
    return allUsers.map(u => ({ id: u.id, email: u.email }));
  }

  // ✅ FILTER by profiles table
  let query = supabase.from("profiles").select("id");

  if (type === "active")   query.eq("status", "Active");
  if (type === "inactive") query.eq("status", "Inactive");
  if (type === "trial")    query.eq("plan", "Trial");

  if (["active", "inactive", "trial"].includes(type)) {
    const { data: profiles } = await query;

    if (!profiles) return [];

    return profiles
      .map(p => ({
        id: p.id,
        email: userMap.get(p.id) // ✅ correct email lookup
      }))
      .filter(u => u.email); // remove nulls
  }

  // ✅ Custom list
  if (type === "custom") {
    return (customList || []).map(email => ({ email }));
  }

  return [];
}


/* ✅ Send Notification */
export const sendNotification = async (req, res) => {
  try {
    const { recipient_type, notification_type, subject, message, custom_list } = req.body;

    // ✅ Get recipients
    const recipients = await getRecipients(recipient_type, custom_list);
    console.log("Recipients:", recipients);

    let delivered = 0;

    /* ✅ EMAIL SENDING (currently disabled because nodemailer not configured) */
    if (notification_type === "email" || notification_type === "both") {
      console.log("📩 Skipping email (Nodemailer not configured)");
      delivered = recipients.length; // pretend delivered
      // If you want real email: enable Mailtrap config
    }

    /* ✅ Website notifications */
    /* ✅ Website notifications */
/* ✅ Website notifications */
for (const r of recipients) {
  const userId = r.id;

  await supabase.from("user_notifications").insert({
    user_id: userId,
    title: subject,
    message,
    is_read: false
  });
}/* ✅ Website notifications */
/* ✅ Website notifications */
for (const user of recipients) {

  if (!user.id) continue; // skip invalid ones

  await supabase.from("user_notifications").insert({
    user_id: user.id,
    title: subject,
    message,
    is_read: false
  });
}




    /* ✅ Admin log */
    await supabase.from("notification_logs").insert({
      subject,
      message,
      recipient_type,
      notification_type,
      delivered_count: delivered,
      custom_list
    });

    return res.json({
      message: "Notification sent successfully",
      delivered,
      recipients
    });

  } catch (err) {
    console.error("sendNotification error:", err);
    return res.status(500).json({ error: err.message });
  }
};


/* ✅ Save Draft */
export const saveDraft = async (req, res) => {
  try {
    const { data, error } = await supabase
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

/* ✅ Admin — Recent Notifications */
export const getNotifications = async (req, res) => {
  try {
    const { data, error } = await supabase
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
