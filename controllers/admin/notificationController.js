// controllers/admin/notificationController.js
import { supabaseAdmin } from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   1️⃣ FETCH ALL USERS (with pagination)
------------------------------------------------------- */
async function fetchAllUsers() {
  // This function is not currently called anywhere in the active code paths.
  // The getRecipients function below uses v_customers view directly.
  // Kept for backwards compatibility.
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("id, email, role, full_name, first_name, last_name, created_at");

  if (error) {
    console.error("❌ fetchAllUsers error:", error);
    return [];
  }

  return data || [];
}

/* -------------------------------------------------------
   2️⃣ GET RECIPIENTS
------------------------------------------------------- */
async function getRecipients(type, customList = []) {
  const { data: customers, error } = await supabaseAdmin
    .from("v_customers")
    .select(`
      id,
      email,
      role,
      account_status,
      subscription_status,
      subscription_plan,
      billing_status
    `);

  if (error) {
    console.error("❌ getRecipients error:", error);
    return [];
  }

  if (!customers?.length) return [];

  return customers.filter((c) => {
    // normalize
    const role = c.role?.toLowerCase();
    const accountStatus = c.account_status?.toLowerCase();
    const subscriptionStatus = c.subscription_status?.toLowerCase();
    const billingStatus = c.billing_status?.toLowerCase();

    // never notify admins
    if (role === "admin") return false;

    switch (type) {
      case "all":
        return accountStatus === "active";

      case "active":
        return subscriptionStatus === "active";

      case "inactive":
        return subscriptionStatus !== "active";

      case "trial":
        return billingStatus === "free";

      case "custom":
        return customList.includes(c.email);

      default:
        return false;
    }
  });
}



/* -------------------------------------------------------
   3️⃣ SEND NOTIFICATION
------------------------------------------------------- */
export const sendNotification = async (req, res) => {
  try {
    const {
      recipient_type,
      notification_type,
      subject,
      message,
      custom_list,
    } = req.body;

    const recipients = await getRecipients(recipient_type, custom_list);

    if (!recipients.length) {
      return res.json({ message: "No recipients found." });
    }

    /* ------------------------------------------------
       1️⃣ INSERT INTO ADMIN LOG (ONCE)
    ------------------------------------------------ */
    const { data: log, error: logError } = await supabaseAdmin
      .from("notification_logs")
      .insert({
        subject,
        message,
        recipient_type,
        notification_type,
        delivered_count: recipients.length,
        custom_list: custom_list || null,
      })
      .select()
      .single();

    if (logError) {
      console.error("❌ notification_logs error:", logError);
      return res.status(500).json({ error: "Failed to log notification" });
    }

    /* ------------------------------------------------
       2️⃣ INSERT INTO USER NOTIFICATIONS (🔥 FIX)
    ------------------------------------------------ */
    const userNotifications = recipients.map((u) => ({
      user_id: u.id,
      title: subject,
      message,
      is_read: false,
    }));

    const { error: userError } = await supabaseAdmin
      .from("user_notifications")
      .insert(userNotifications);

    if (userError) {
      console.error("❌ user_notifications insert error:", userError);
      return res.status(500).json({ error: "Failed to notify users" });
    }

    return res.json({
      message: "Notification sent successfully",
      delivered: recipients.length,
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
