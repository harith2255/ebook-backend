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
    const { error } = await supabase
      .from("profiles")
      .update({ status: "Suspended" })
      .eq("id", id);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Customer suspended" });
  } catch (err) {
    console.error("suspendCustomer error:", err);
    res.status(500).json({ error: "Server error suspending customer" });
  }
};

export const activateCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase
      .from("profiles")
      .update({ status: "Active" })
      .eq("id", id);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Customer activated" });
  } catch (err) {
    console.error("activateCustomer error:", err);
    res.status(500).json({ error: "Server error activating customer" });
  }
};

/* ---------------------------------------------------------
   EMAIL CUSTOMER
--------------------------------------------------------- */
export const sendEmailToCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const { subject, text, html } = req.body;

    if (!subject || (!text && !html)) {
      return res
        .status(400)
        .json({ error: "subject and text or html required" });
    }

    const { data: userData, error: userErr } =
      await supabase.auth.admin.getUserById(id);

    if (userErr) {
      return res.status(400).json({ error: userErr.message });
    }

    const userEmail = userData?.user?.email;

    if (!userEmail) {
      return res.status(404).json({ error: "Email not found" });
    }

    if (process.env.NODE_ENV !== "production") {
      console.log("📩 Mock email (development mode)");
      console.log("To:", userEmail);
      console.log("Subject:", subject);
      console.log("Text:", text);
      console.log("HTML:", html || "");
      return res.json({ message: "Mock email printed to console" });
    }

    await transporter.sendMail({
      from: process.env.MAIL_FROM || "Support <no-reply@yourapp.com>",
      to: userEmail,
      subject,
      text,
      html,
    });

    res.json({ message: "Email sent" });
  } catch (err) {
    console.error("sendEmailToCustomer error:", err);
    res.status(500).json({ error: "Server error sending email" });
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
