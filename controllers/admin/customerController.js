// controllers/customerController.js
import {
  supabaseAdmin,
  supabasePublic
} from "../../utils/supabaseClient.js";

import nodemailer from "nodemailer";

/* ---------------------------------------------------------
   GET /admin/customers (search + pagination)
--------------------------------------------------------- */
export const listCustomers = async (req, res) => {
  try {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 10));
    const start = (page - 1) * limit;
    const end = start + limit - 1;

    const { search, status, plan } = req.query;

 let query = supabaseAdmin
  .from("v_customers")
  .select("*", { count: "exact" });

const ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL?.toLowerCase();
if (ADMIN_EMAIL) {
  query = query.neq("email", ADMIN_EMAIL);
}

if (status) query = query.eq("account_status", status);
if (plan) query = query.eq("subscription_plan", plan);

if (search) {
  query = query.or(
    `full_name.ilike.%${search}%,email.ilike.%${search}%`
  );
}


    const { data, count, error } = await query
      .order("created_at", { ascending: false })
      .range(start, end);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json({
      data,
      total: count ?? 0,
      page,
      totalPages: Math.ceil((count ?? 0) / limit),
    });
  } catch (err) {
    console.error("listCustomers error:", err);
    res.status(500).json({ error: "Server error listing customers" });
  }
};



/* ---------------------------------------------------------
   SUSPEND USER
--------------------------------------------------------- */
export const suspendCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    // Update real column
    const { error: profileError } = await supabaseAdmin
      .from("profiles")
     .update({ account_status: "suspended" })

      .eq("id", id);

    if (profileError) {
      return res.status(400).json({ error: profileError.message });
    }

    // Block login + revoke sessions
    const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(id, {
      ban_until: "9999-12-31T23:59:59Z",
      revoke_tokens: true,
    });

    if (authError) {
      return res.status(400).json({ error: authError.message });
    }

    res.json({ message: "Customer suspended successfully" });
  } catch (err) {
    console.error("suspendCustomer error:", err);
    res.status(500).json({ error: "Server error suspending customer" });
  }
};




/* ---------------------------------------------------------
   ACTIVATE USER
--------------------------------------------------------- */
export const activateCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .update({ account_status: "active" })   // ✔ FIXED
      .eq("id", id);

    if (profileError) {
      return res.status(400).json({ error: profileError.message });
    }

   await supabaseAdmin.auth.admin.updateUserById(id, {
  ban_until: "1970-01-01T00:00:00Z", // 👈 unban properly
  revoke_tokens: true,
});


    res.json({ message: "Customer activated successfully" });
  } catch (err) {
    console.error("activateCustomer error:", err);
    res.status(500).json({ error: "Server error activating customer" });
  }
};






/* ---------------------------------------------------------
   EMAIL / NOTIFICATIONS
--------------------------------------------------------- */
export const sendNotificationToCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, message, link } = req.body;

    if (!title || !message) {
      return res.status(400).json({ error: "title and message required" });
    }

    const payload = {
      user_id: id,
      title,
      message,
      link: link || "dashboard",
      is_read: false,
      created_at: new Date().toISOString(),
    };

    const { error } = await supabaseAdmin.from("user_notifications").insert(payload);

    if (error)
      return res.status(400).json({ error: error.message });

    res.json({ message: "Notification sent" });

  } catch (err) {
    console.error("sendNotificationToCustomer error:", err);
    res.status(500).json({ error: "Server error sending notification" });
  }
};



/* ---------------------------------------------------------
   SUBSCRIPTION HISTORY
--------------------------------------------------------- */
export const getSubscriptionHistory = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from("subscriptions")
      .select("*")
      .eq("user_id", id)
      .order("created_at", { ascending: false });

    if (error)
      return res.status(400).json({ error: error.message });

    res.json({ subscriptions: data });

  } catch (err) {
    console.error("getSubscriptionHistory error:", err);
    res.status(500).json({ error: "Server error" });
  }
};



/* ---------------------------------------------------------
   ADD SUBSCRIPTION
--------------------------------------------------------- */
export const addSubscription = async (req, res) => {
  try {
    const { id } = req.params;
    const { plan, amount, status } = req.body;

    if (!plan || amount == null) {
      return res.status(400).json({ error: "plan and amount are required" });
    }

    const { data } = await supabaseAdmin
      .from("subscriptions")
      .insert([
        {
          user_id: id,
          plan,
          amount,
          status: status ?? "active",
          start_date: new Date(),
        },
      ])
      .select()
      .single();

    // Update total spent
    const { data: profileRow } = await supabaseAdmin
      .from("profiles")
      .select("total_spent")
      .eq("id", id)
      .single();

    const newTotal = Number(profileRow?.total_spent || 0) + Number(data.amount);

    await supabaseAdmin
      .from("profiles")
      .update({ total_spent: newTotal })
      .eq("id", id);

    res.status(201).json({
      message: "Subscription added",
      subscription: data
    });

  } catch (err) {
    console.error("addSubscription error:", err);
    res.status(500).json({ error: "Server error" });
  }
};



/* ---------------------------------------------------------
   DELETE CUSTOMER (AUTH + ALL TABLES)
--------------------------------------------------------- */
export const deleteCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    /* -----------------------------------------
       1. DELETE ALL CHILD TABLE DATA FIRST
    ----------------------------------------- */
    const tablesToClean = [
      "downloaded_notes",
      "ebooks",
      "mock_answers",
      "mock_attempts",
      "mock_tests",
      "test_attempts",
      "test_results",
      "activity_log",
      "user_books",
      "user_cart",
      "user_library",
      "user_subscriptions",
      "notes_purchase",
      "notes",
      "writing_feedback",
      "writing_orders",
      "payment_methods",
      "payments_transactions",
      "saved_jobs",
      "purchases",
      "jobs_applications",
      "subscriptions"
    ];

    for (const table of tablesToClean) {
      await supabaseAdmin.from(table).delete().eq("user_id", id);
    }

    /* -----------------------------------------
       2. DELETE PROFILE
    ----------------------------------------- */
    await supabaseAdmin.from("profiles").delete().eq("id", id);

    /* -----------------------------------------
       3. DELETE THE AUTH USER (ignore harmless errors)
    ----------------------------------------- */
    const { error: authErr } = await supabaseAdmin.auth.admin.deleteUser(id);

    if (authErr) {
      console.warn("Auth delete warning:", authErr.message);

      if (
        !authErr.message.includes("not found") &&
        !authErr.message.includes("Database error deleting user")
      ) {
        return res.status(400).json({ error: authErr.message });
      }
    }

    res.json({ message: "User fully deleted" });

  } catch (err) {
    console.error("deleteCustomer error:", err);
    res.status(500).json({ error: "Server error" });
  }
};
