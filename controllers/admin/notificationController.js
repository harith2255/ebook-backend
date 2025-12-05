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
  // always fetch customers instead of auth.users
  const { data: customers, error } = await supabaseAdmin
    .from("v_customers")
    .select("id, email, status, plan");

  if (!customers?.length) return [];

  switch (type) {
    case "all":
    

      return customers.filter(c => 
  c.status === "Active" &&
  !c.email.includes("admin")
);


    case "active":
      return customers.filter(c => c.status === "Active");

    case "inactive":
      return customers.filter(c => c.status !== "Active");

    case "trial":
      return customers.filter(c => c.plan === "Trial");

    case "custom":
      return customers.filter(c => customList.includes(c.email));

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

    let delivered = recipients.length; // count unique users only


    /* -----------------------------
       📝 LOG ACTION (ONE ENTRY ONLY)
    ------------------------------- */
    const { data, error } = await supabaseAdmin
  .from("notification_logs")
  .insert({
    subject,
    message,
    recipient_type,
    notification_type,      // REQUIRED!
    delivered_count: delivered,
    custom_list: Array.isArray(custom_list) ? custom_list : null,
  })
  .select()
  .single();

if (error) {
  console.error("❌ notification_logs insert error:", error);
}

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
