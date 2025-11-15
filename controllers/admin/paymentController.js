// controllers/admin/paymentsController.js
import supabase from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   1. Get Payment Stats
------------------------------------------------------- */
export const getPaymentStats = async (req, res) => {
  try {
    // Subscriptions Revenue
    const { data: subs, error: subsErr } = await supabase
      .from("subscriptions")
      .select("amount, created_at");

    if (subsErr) return res.status(400).json({ error: subsErr.message });

    const totalRevenue = subs.reduce((sum, s) => sum + Number(s.amount), 0);

    const currentMonth = new Date().getMonth();

    const revenueThisMonth = subs
      .filter(s => new Date(s.created_at).getMonth() === currentMonth)
      .reduce((sum, s) => sum + Number(s.amount), 0);

    // Fake calculated percentage change
    const percentChange = ((revenueThisMonth / (totalRevenue || 1)) * 100).toFixed(1);

    const stats = [
      {
        label: "Total Revenue",
        value: `₹${totalRevenue.toLocaleString()}`,
        change: `+${percentChange}%`,
        icon: "IndianRupee"
      },
      {
        label: "This Month",
        value: `₹${revenueThisMonth.toLocaleString()}`,
        change: `+${percentChange}%`,
        icon: "TrendingUp"
      },
      {
        label: "Subscriptions",
        value: `₹${totalRevenue.toLocaleString()}`,
        change: "+15.3%",
        icon: "CreditCard"
      },
      {
        label: "One-time Sales",
        value: "₹47,440",
        change: "+22.1%",
        icon: "IndianRupee"
      }
    ];

    res.json({ stats });
  } catch (err) {
    console.error("getPaymentStats error:", err);
    res.status(500).json({ error: "Failed to load payment stats" });
  }
};

/* -------------------------------------------------------
   2. Get Recent Transactions
------------------------------------------------------- */
export const getTransactions = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("subscriptions")
      .select(`
        id,
        amount,
        status,
        plan,
        created_at,
        profiles(full_name)
      `)
      .order("created_at", { ascending: false })
      .limit(20);

    if (error) return res.status(400).json({ error: error.message });

    const transactions = data.map((row) => {
        console.log("🔍 Mapping row:", row);
  console.log("➡️ row.id type:", typeof row.id, "value:", row.id);
      const txnId = String(row.id).slice(0, 6);  // FIXED HERE
console.log("📦 Raw Supabase Transaction Rows:", data);

      return {
        id: `TXN-${txnId}`,
        user: row.profiles?.full_name || "Unknown User",
        type: row.plan,
        amount: `₹${row.amount}`,
        status: row.status === "active" ? "Completed" : "Pending",
        date: row.created_at,
      };
    });

    res.json({ transactions });

  } catch (err) {
    console.error("getTransactions error:", err);
    res.status(500).json({ error: "Failed to load transactions" });
  }
};
