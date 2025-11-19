import { supabaseAdmin } from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   AUTO-DETECT TABLE
------------------------------------------------------- */
async function detectPaymentsTable() {
  const tables = ["payments_transactions", "payments", "transactions", "orders"];

  for (let t of tables) {
    const { data, error } = await supabaseAdmin
      .from(t)
      .select("*")
      .limit(1);

    if (!error) return t; // found a valid table
  }

  return null;
}

/* -------------------------------------------------------
   AUTO-DETECT PAYMENT COLUMNS
------------------------------------------------------- */
function extractColumns(record) {
  if (!record) return {};

  return {
    id: record.id ?? null,
    amount: Number(record.amount ?? 0),
    status: record.status ?? "Unknown",
    method: record.method ?? record.payment_method ?? "N/A",
    description: record.description ?? record.type ?? "Payment",
    created_at: record.created_at ?? record.date ?? new Date().toISOString(),
    user_id: record.user_id ?? record.uid ?? null,
  };
}

/* -------------------------------------------------------
   AUTO-DETECT USER NAME
------------------------------------------------------- */
async function resolveUserName(user_id) {
  if (!user_id) return "Unknown";

  // Try local profiles table
  let { data: p1 } = await supabaseAdmin
    .from("profiles")
    .select("full_name")
    .eq("id", user_id)
    .single();

  if (p1?.full_name) return p1.full_name;

  // Try users_metadata
  let { data: p2 } = await supabaseAdmin
    .from("users_metadata")
    .select("full_name")
    .eq("id", user_id)
    .single();

  if (p2?.full_name) return p2.full_name;

  // Try auth.users (email fallback)
  let { data: p3 } = await supabaseAdmin
    .from("auth.users")
    .select("email")
    .eq("id", user_id)
    .single();

  return p3?.email ?? "Unknown";
}

/* -------------------------------------------------------
   1. 📊 Dynamic Payment Stats
------------------------------------------------------- */
// controllers/admin/paymentsController.js
import supabase from "../../utils/supabaseClient.js";

export const getPaymentStats = async (req, res) => {
  try {
    // Fetch all transactions
    const { data: payments, error } = await supabase
      .from("payments_transactions")
      .select("*");

    if (error) return res.status(400).json({ error: error.message });

    // Totals
    const totalRevenue = payments.reduce((sum, p) => sum + Number(p.amount), 0);

    // Monthly calculations
    const now = new Date();
    const currentMonth = now.getMonth();
    const currentYear = now.getFullYear();

    const lastMonth = (currentMonth === 0 ? 11 : currentMonth - 1);
    const lastMonthYear = (currentMonth === 0 ? currentYear - 1 : currentYear);

    const thisMonthRevenue = payments
      .filter(p => {
        const d = new Date(p.created_at);
        return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
      })
      .reduce((sum, p) => sum + Number(p.amount), 0);

    const lastMonthRevenue = payments
      .filter(p => {
        const d = new Date(p.created_at);
        return d.getMonth() === lastMonth && d.getFullYear() === lastMonthYear;
      })
      .reduce((sum, p) => sum + Number(p.amount), 0);

    // Growth %
    const growth = lastMonthRevenue
      ? (((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100).toFixed(1)
      : thisMonthRevenue > 0 ? "100" : "0";

    // Payment status analytics
    const completedPayments = payments.filter(p => p.status === "Completed").length;
    const pendingPayments = payments.filter(p => p.status === "Pending").length;

    const stats = [
      {
        label: "Total Revenue",
        value: `₹${totalRevenue.toLocaleString()}`,
        change: `${growth}%`,
        icon: "IndianRupee",
      },
      {
        label: "This Month",
        value: `₹${thisMonthRevenue.toLocaleString()}`,
        change: `${growth}%`,
        icon: "TrendingUp",
      },
      {
        label: "Total Payments",
        value: payments.length,
        change: "+Auto",
        icon: "CreditCard",
      },
      {
        label: "Completed Payments",
        value: completedPayments,
        change: "+Auto",
        icon: "IndianRupee",
      }
    ];

    res.json({ stats });

  } catch (err) {
    console.error("getPaymentStats error:", err);
    res.status(500).json({ error: "Failed to load payment stats" });
  }
};


/* -------------------------------------------------------
   2. 💳 Dynamic Transactions
------------------------------------------------------- */
export const getTransactions = async (req, res) => {
  try {
    const table = await detectPaymentsTable();
    if (!table) return res.status(500).json({ error: "No payments table found." });

    // Fetch all transactions
    const { data, error } = await supabaseAdmin
      .from(table)
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    const extracted = await Promise.all(
      data.map(async (row) => {
        const p = extractColumns(row);
        return {
          id: p.id,
          amount: `₹${p.amount}`,
          status: p.status,
          type: p.description,
          date: p.created_at,
          user: await resolveUserName(p.user_id),
        };
      })
    );

    res.json({ transactions: extracted });
  } catch (err) {
    console.error("Dynamic Transactions Error:", err);
    res.status(500).json({ error: "Failed to load transactions dynamically" });
  }
};
