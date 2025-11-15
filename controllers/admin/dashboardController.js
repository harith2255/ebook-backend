import supabase from "../../utils/supabaseClient.js";

const formatMonth = (date) =>
  new Date(date).toLocaleString("en-US", { month: "short" });

/* -------------------------------------------------------
   🔥 Helper: Percentage Change
   Returns clean value:
   → +12.5
   → -8.3
   → 0
------------------------------------------------------- */
function percentChange(current, previous) {
  current = Number(current) || 0;
  previous = Number(previous) || 0;

  if (previous === 0) return 0;

  return Number((((current - previous) / previous) * 100).toFixed(1));
}



export const getAdminDashboard = async (req, res) => {
  try {
    /* -------------------------------------------------------
       1. TOTAL USERS (AUTH USERS)
    ------------------------------------------------------- */
    const { data: authUsers, error: userErr } =
      await supabase.auth.admin.listUsers();

    if (userErr) console.log("User Count Error:", userErr);

    const allUsers = authUsers?.users || [];
    const totalUsers = allUsers.length;

    /* -------------------------------------------------------
       2. ACTIVE SUBSCRIPTIONS
    ------------------------------------------------------- */
    const { count: activeSubs } = await supabase
      .from("subscriptions")
      .select("*", { count: "exact", head: true })
      .eq("status", "active");

    /* -------------------------------------------------------
       3. BOOKS SOLD
    ------------------------------------------------------- */
    const { count: booksSold } = await supabase
      .from("book_sales")
      .select("*", { count: "exact", head: true });

    /* -------------------------------------------------------
       4. REVENUE MTD
    ------------------------------------------------------- */
    const firstDay = new Date();
    firstDay.setDate(1);

    const { data: revenueMonth } = await supabase
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", firstDay.toISOString());

    const revenueMTD =
      revenueMonth?.reduce((s, r) => s + Number(r.amount), 0) || 0;

    /* -------------------------------------------------------
       5. LAST 6 MONTHS REVENUE TREND
    ------------------------------------------------------- */
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const { data: revRows } = await supabase
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", sixMonthsAgo.toISOString());

    const revenueTrend = {};

    revRows?.forEach((r) => {
      const m = formatMonth(r.created_at);
      revenueTrend[m] = (revenueTrend[m] || 0) + Number(r.amount);
    });

    /* -------------------------------------------------------
       6. USER SIGNUPS TREND (AUTH USERS)
    ------------------------------------------------------- */
    const newUsers = allUsers.filter(
      (u) => new Date(u.created_at) >= sixMonthsAgo
    );

    const userGrowthTrend = {};

    newUsers.forEach((u) => {
      const m = formatMonth(u.created_at);
      userGrowthTrend[m] = (userGrowthTrend[m] || 0) + 1;
    });

    /* -------------------------------------------------------
       7. SORT MONTHS FOR CHART
    ------------------------------------------------------- */
    const months = [
      ...new Set([...Object.keys(revenueTrend), ...Object.keys(userGrowthTrend)])
    ];

    const monthOrder = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    const sortedMonths = months.sort(
      (a, b) => monthOrder.indexOf(a) - monthOrder.indexOf(b)
    );

    const chartData = sortedMonths.map((m) => ({
      month: m,
      revenue: revenueTrend[m] || 0,
      users: userGrowthTrend[m] || 0,
    }));

    
  
/* -------------------------------------------------------
   8. CLEAN KPI % CHANGE CALCULATION (SAFE)
------------------------------------------------------- */
console.log("DEBUG KPI VALUES:");
console.log("totalUsers:", totalUsers);
console.log("activeSubs:", activeSubs);
console.log("booksSold:", booksSold);
console.log("revenueMTD:", revenueMTD);

console.log("TREND DATA:");
console.log("sortedMonths:", sortedMonths);
console.log("userGrowthTrend:", userGrowthTrend);
console.log("revenueTrend:", revenueTrend);


/* =======================
   SAFE KPI % CALCULATION
========================== */

// previous month key
const prevMonthKey =
  sortedMonths.length >= 2 ? sortedMonths[sortedMonths.length - 2] : null;

// safe previous values
const prevUsers = Number(userGrowthTrend[prevMonthKey] || 0);
const prevRevenue = Number(revenueTrend[prevMonthKey] || 0);

// fallback previous values (avoid division by zero)
const prevBooks = booksSold > 1 ? booksSold - 1 : 1;
const prevSubs = activeSubs > 1 ? activeSubs - 1 : 1;

// final percentages
const userGrowthPercent = percentChange(newUsers.length, prevUsers);
const revenueGrowthPercent = percentChange(revenueMTD, prevRevenue);
const booksGrowthPercent = percentChange(booksSold, prevBooks);
const subsGrowthPercent = percentChange(activeSubs, prevSubs);




    /* -------------------------------------------------------
       9. RECENT ACTIVITY
    ------------------------------------------------------- */
    const { data: recentActivity } = await supabase
      .from("activity_log")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(20);

    /* -------------------------------------------------------
       10. SEND FINAL RESPONSE
    ------------------------------------------------------- */
    return res.json({
      kpis: {
        totalUsers,
        activeSubs,
        booksSold,
        revenueMTD,
        userGrowthPercent,
        revenueGrowthPercent,
        booksGrowthPercent,
        subsGrowthPercent,
      },
      chartData,
      recentActivity,
    });

  } catch (error) {
    console.error("Dashboard error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};
