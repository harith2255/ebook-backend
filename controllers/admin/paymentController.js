// controllers/admin/paymentsController.js
import { supabaseAdmin } from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   HELPERS
------------------------------------------------------- */

// Small helper for month label (e.g. "Jan")
const formatMonth = (date) =>
  new Date(date).toLocaleString("en-US", { month: "short" });

function percentChange(current, previous) {
  current = Number(current) || 0;
  previous = Number(previous) || 0;

  if (previous === 0) {
    if (current === 0) return 0;
    return 100; // treat as 100% growth from 0 -> something
  }

  return Number((((current - previous) / previous) * 100).toFixed(1));
}

function formatPercent(pct) {
  const n = Number(pct) || 0;
  const sign = n > 0 ? "+" : "";
  return `${sign}${n}%`;
}

function isCompletedStatus(status) {
  if (!status) return false;
  const s = String(status).toLowerCase();
  // extend this list if you have more "success" statuses
  return ["completed", "paid", "success", "succeeded"].includes(s);
}

/* -------------------------------------------------------
   AUTO-DETECT PAYMENT COLUMNS (still dynamic)
------------------------------------------------------- */
function extractColumns(record) {
  if (!record) return {};

  return {
    id: record.id ?? null,
    amount: Number(record.amount ?? 0),
    status: record.status ?? record.payment_status ?? "Unknown",
    method: record.method ?? record.payment_method ?? "N/A",
    description: record.description ?? record.type ?? record.item_type ?? "Payment",
    created_at: record.created_at ?? record.date ?? new Date().toISOString(),
    user_id: record.user_id ?? record.uid ?? record.customer_id ?? null,
  };
}

/* -------------------------------------------------------
   AUTO-DETECT USER NAME
------------------------------------------------------- */
async function resolveUserName(user_id) {
  if (!user_id) return "Unknown";

  try {
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
  } catch (err) {
    console.error("resolveUserName error:", err);
    return "Unknown";
  }
}

/* -------------------------------------------------------
   1. 📊 Dynamic Payment Stats (uses revenue table)
------------------------------------------------------- */
export const getPaymentStats = async (req, res) => {
  try {
    /* === 1. Total revenue (from revenue table) === */
    const { data: revenueRows } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at");

    const totalRevenue = revenueRows.reduce(
      (sum, r) => sum + Number(r.amount || 0),
      0
    );


    /* === 2. Total payments (from payments_transactions) === */
    const { count: totalPayments, error: payErr } = await supabaseAdmin
      .from("payments_transactions")
      .select("*", { count: "exact", head: true });

    if (payErr) console.error("payments_transactions error:", payErr);


    /* === 3. Completed payments === */
    const { count: totalCompleted, error: compErr } = await supabaseAdmin
      .from("payments_transactions")
      .select("*", { count: "exact", head: true })
      .eq("status", "completed");

    if (compErr) console.error("completed error:", compErr);


    /* === 4. Monthly revenue (revenue table) === */
    const now = new Date();
    const currentMonth = now.getMonth();
    const currentYear = now.getFullYear();

    const thisMonthRevenue = revenueRows
      .filter((r) => {
        const d = new Date(r.created_at);
        return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
      })
      .reduce((sum, r) => sum + Number(r.amount || 0), 0);


    /* === 5. Build stats === */
    const stats = [
      {
        label: "Total Revenue",
        value: `₹${totalRevenue.toLocaleString()}`,
       
        icon: "IndianRupee",
      },
      {
        label: "This Month",
        value: `₹${thisMonthRevenue.toLocaleString()}`,
       
        icon: "TrendingUp",
      },
      {
        label: "Total Payments",
        value: totalPayments || 0,
      
        icon: "CreditCard",
      },
      {
        label: "Completed Payments",
        value: totalCompleted || 0,
       
        icon: "IndianRupee",
      },
    ];

    return res.json({ stats });

  } catch (err) {
    console.error("getPaymentStats error:", err);
    return res.status(500).json({ error: "Failed to load payment stats" });
  }
};



/* -------------------------------------------------------
   2. 💳 Dynamic Transactions (from revenue + pagination)
------------------------------------------------------- */
export const getTransactions = async (req, res) => {
  try {
    const page = Number(req.query.page) || 1;
    const limit = Number(req.query.limit) || 10;
    const start = (page - 1) * limit;
    const end = start + limit - 1;

    const { data, error, count } = await supabaseAdmin
      .from("revenue")
      .select(`
        id,
        amount,
        created_at,
        user_id,
        item_type,
        payments_transactions (
          method,
          status,
          description
        )
      `, { count: "exact" })
      .order("created_at", { ascending: false })
      .range(start, end);

    if (error) {
      console.error("revenue list error:", error);
      return res.status(400).json({ error: error.message });
    }

    const result = await Promise.all(
      data.map(async (row) => {
        const p = row.payment_transactions;

        return {
          id: row.id,
          amount: `₹${Number(row.amount)}`,
          status: (p?.status || "completed").toLowerCase(),
          type: p?.description || row.item_type || "payment",
          method: p?.method || "manual",
          date: row.created_at,
          user: await resolveUserName(row.user_id),
        };
      })
    );

    res.json({
      transactions: result,
      pagination: {
        page,
        limit,
        total: count,
        totalPages: Math.ceil(count / limit),
      },
    });
  } catch (err) {
    console.error("getTransactions error:", err);
    res.status(500).json({ error: "Failed to load transactions dynamically" });
  }
};
