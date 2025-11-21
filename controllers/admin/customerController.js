// controllers/customerController.js
import supabase from "../../utils/supabaseClient.js";

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

    let query = supabase.from("v_customers").select("*", { count: "exact" });

    if (status) query = query.eq("status", status);
    if (plan) query = query.eq("plan", plan);

    if (search) {
      query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%`);
    }

    const { data, count, error } = await query
      .order("joined", { ascending: false })
      .range(start, end);

    if (error) return res.status(400).json({ error: error.message });

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
   SUSPEND / ACTIVATE USER
--------------------------------------------------------- */
export const suspendCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    console.log("⚠️ Suspend request for:", id);

    // 1. Update profiles table
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ status: "Suspended" })
      .eq("id", id);

    if (profileError)
      return res.status(400).json({ error: profileError.message });

    // 2. Auth: Set permanent ban
    const { error: authError } = await supabase.auth.admin.updateUserById(id, {
      ban_until: new Date("9999-12-31T23:59:59Z").toISOString(),
    });

    if (authError)
      return res.status(400).json({ error: authError.message });

    res.json({ message: "Customer suspended successfully" });
  } catch (err) {
    console.error("suspendCustomer error:", err);
    res.status(500).json({ error: "Server error suspending customer" });
  }
};



export const activateCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    // 1. Update profiles table
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ status: "Active" })
      .eq("id", id);

    if (profileError)
      return res.status(400).json({ error: profileError.message });

    // 2. Remove ban
    const { error: authError } = await supabase.auth.admin.updateUserById(id, {
      ban_until: null,
    });

    if (authError)
      return res.status(400).json({ error: authError.message });

    res.json({ message: "Customer activated successfully" });
  } catch (err) {
    console.error("activateCustomer error:", err);
    res.status(500).json({ error: "Server error activating customer" });
  }
};



/* ---------------------------------------------------------
   EMAIL CUSTOMER
--------------------------------------------------------- */
export const sendNotificationToCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, message, link } = req.body;

    if (!title || !message) {
      return res.status(400).json({ error: "title and message required" });
    }

    // Force only valid DB columns
    const payload = {
      user_id: id,
      title,
      message,
      link: link || "dashboard",
      is_read: false,  // correct column
      created_at: new Date().toISOString(),
    };

    const { error } = await supabase
      .from("user_notifications")
      .insert(payload);

    if (error) {
      console.error("Supabase Insert Error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.json({ message: "Notification sent" });
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

    const { data, error } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("user_id", id)
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ subscriptions: data });
  } catch (err) {
    console.error("getSubscriptionHistory error:", err);
    res.status(500).json({ error: "Server error getting subscriptions" });
  }
};

/* ---------------------------------------------------------
   ADD SUBSCRIPTION
--------------------------------------------------------- */
export const addSubscription = async (req, res) => {
  try {
    const { id } = req.params;
    const { plan, amount, status, start_date, end_date } = req.body;

    if (!plan || amount == null) {
      return res
        .status(400)
        .json({ error: "plan and amount are required" });
    }

    const { data, error } = await supabase
      .from("subscriptions")
      .insert([
        {
          user_id: id,
          plan,
          amount,
          status: status ?? "active",
          start_date: start_date ?? new Date(),
          end_date: end_date ?? null,
        },
      ])
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    const { data: profileRow } = await supabase
      .from("profiles")
      .select("total_spent")
      .eq("id", id)
      .single();

    const newTotal =
      Number(profileRow?.total_spent || 0) + Number(data.amount);

    await supabase
      .from("profiles")
      .update({ total_spent: newTotal })
      .eq("id", id);

    res
      .status(201)
      .json({ message: "Subscription added", subscription: data });
  } catch (err) {
    console.error("addSubscription error:", err);
    res.status(500).json({ error: "Server error adding subscription" });
  }
};

/* ---------------------------------------------------------
   DELETE CUSTOMER (Auth User + Profile)
--------------------------------------------------------- */
/* ---------------------------------------------------------
   DELETE CUSTOMER (Auth + All Related Tables)
--------------------------------------------------------- */
export const deleteCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    console.log("Deleting user:", id);

    // 1️⃣ DELETE ALL RELATED TABLES FIRST
    const tablesToClean = [
      "profiles",
      "subscriptions",
      "book_sales",
      "activity_log",
      "user_notifications",
      "payments_transactions",
      "writing_orders",
      "notes",
      "purchases",
      "mock_test_attempts",
      "jobs_applications"
    ];

    for (const table of tablesToClean) {
      await supabase.from(table).delete().eq("user_id", id);
    }

    // ❗ profiles table uses id not user_id
    await supabase.from("profiles").delete().eq("id", id);

    // 2️⃣ DELETE FROM AUTH
    const { error: authErr } = await supabase.auth.admin.deleteUser(id);

    if (authErr) {
      console.error("Auth delete error:", authErr.message);
      return res.status(400).json({ error: authErr.message });
    }

    // 3️⃣ SUCCESS
    res.json({
      message: "User deleted from auth + all related tables successfully",
    });

  } catch (err) {
    console.error("deleteCustomer error:", err);
    return res.status(500).json({
      error: "Server error deleting customer",
    });
  }
};
