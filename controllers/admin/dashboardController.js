import { supabaseAdmin } from "../../utils/supabaseClient.js";

// Format month name from date
const formatMonth = (d) =>
  new Date(d).toLocaleString("en-US", { month: "short" });

// Percent change helper
function percentChange(current, previous) {
  current = Number(current) || 0;
  previous = Number(previous) || 0;
  if (previous === 0) return 0;
  return Number((((current - previous) / previous) * 100).toFixed(1));
}

export const getAdminDashboard = async (req, res) => {
  try {
    /* ======================================================
       USERS
    ====================================================== */
    const { data: customers, error: customersErr } = await supabaseAdmin
      .from("v_customers")
      .select("id, created_at");

    if (customersErr) {
      console.error("v_customers error:", customersErr);
      return res.status(500).json({ error: "Failed to fetch user data" });
    }

    const totalUsers = customers?.length || 0;
    const nowISO = new Date().toISOString();

    /* ======================================================
       ACTIVE SUBSCRIPTIONS
    ====================================================== */
    const { count: activeSubs, error: subsErr } = await supabaseAdmin
      .from("user_subscriptions")
      .select("*", { count: "exact", head: true })
      .eq("status", "active")
      .gte("expires_at", nowISO);

    if (subsErr) {
      console.error("subscriptions error:", subsErr);
    }

    /* ======================================================
       BOOKS SOLD
    ====================================================== */
    const { count: booksSold, error: booksErr } = await supabaseAdmin
      .from("revenue")
      .select("id", { count: "exact", head: true })
      .eq("item_type", "book");

    if (booksErr) {
      console.error("books error:", booksErr);
    }

    /* ======================================================
       REVENUE MTD
    ====================================================== */
    const firstDay = new Date();
    firstDay.setDate(1);

    const { data: revenueMonth, error: revMonthErr } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", firstDay.toISOString());

    if (revMonthErr) {
      console.error("revenue MTD error:", revMonthErr);
    }

    const revenueMTD =
      revenueMonth?.reduce((sum, r) => sum + Number(r.amount), 0) || 0;

    /* ======================================================
       REVENUE TREND 6 MONTHS
    ====================================================== */
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const { data: rows, error: trendErr } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", sixMonthsAgo.toISOString());

    if (trendErr) {
      console.error("revenue trend error:", trendErr);
    }

    const revenueTrend = {};
    rows?.forEach((r) => {
      const m = formatMonth(r.created_at);
      revenueTrend[m] = (revenueTrend[m] || 0) + Number(r.amount);
    });

    /* ======================================================
       USER SIGNUP TREND
    ====================================================== */
    const recentUsers = customers?.filter(
      (u) => u.created_at && new Date(u.created_at) >= sixMonthsAgo
    );

    const userTrend = {};
    recentUsers?.forEach((u) => {
      const m = formatMonth(u.created_at);
      userTrend[m] = (userTrend[m] || 0) + 1;
    });

    /* ======================================================
       MERGE TRENDS FOR CHART
    ====================================================== */
    const months = [...new Set([...Object.keys(revenueTrend), ...Object.keys(userTrend)])];

    const monthOrder = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];

    const sortedMonths = months.sort(
      (a, b) => monthOrder.indexOf(a) - monthOrder.indexOf(b)
    );

    const chartData = sortedMonths.map((m) => ({
      month: m,
      revenue: revenueTrend[m] || 0,
      users: userTrend[m] || 0,
    }));

    /* ======================================================
       KPI % DIFF
    ====================================================== */
    const prevMonth = sortedMonths.length >= 2
      ? sortedMonths[sortedMonths.length - 2]
      : null;

    const prevUsers = userTrend[prevMonth] || 0;
    const prevRevenue = revenueTrend[prevMonth] || 0;

    const userGrowthPercent = percentChange(recentUsers?.length, prevUsers);
    const revenueGrowthPercent = percentChange(revenueMTD, prevRevenue);

    const prevBooks = booksSold > 1 ? booksSold - 1 : 1;
    const prevSubs = activeSubs > 1 ? activeSubs - 1 : 1;

    const booksGrowthPercent = percentChange(booksSold, prevBooks);
    const subsGrowthPercent = percentChange(activeSubs, prevSubs);

    /* ======================================================
       RECENT ACTIVITY (Exclude Login)
    ====================================================== */
    const page = Number(req.query.page) || 1;
    const limit = 10;
    const start = (page - 1) * limit;
    const end = start + limit - 1;

    const { data: activities, count, error: actErr } = await supabaseAdmin
      .from("activity_log")
      .select("*", { count: "exact" })
      .neq("type", "login") // remove login spam
      .order("created_at", { ascending: false })
      .range(start, end);

    if (actErr) {
      console.error("activity error:", actErr);
    }

    const totalPages = Math.ceil((count || 0) / limit);

    /* ======================================================
       RESPONSE
    ====================================================== */
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
      recentActivity: activities || [],
      activityPagination: {
        page,
        totalPages,
        total: count || 0,
      },
    });

  } catch (err) {
    console.error("Dashboard error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};
