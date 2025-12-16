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
    const now = new Date();
    const nowISO = now.toISOString();

    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
    const sixMonthsAgo = new Date(now);
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const page = Number(req.query.page) || 1;
    const limit = 10;
    const start = (page - 1) * limit;
    const end = start + limit - 1;

    /* ======================================================
       PARALLEL DB QUERIES (BIG SPEED GAIN)
    ====================================================== */
    const [
      customersRes,
      activeSubsRes,
      booksSoldRes,
      revenueMonthRes,
      revenueTrendRes,
      activityRes,
    ] = await Promise.all([
      // USERS (id + created_at only, same as before)
      supabaseAdmin
        .from("v_customers")
        .select("id, created_at"),

      // ACTIVE SUBSCRIPTIONS
      supabaseAdmin
        .from("user_subscriptions")
        .select("*", { count: "exact", head: true })
        .eq("status", "active")
        .gte("expires_at", nowISO),

      // BOOKS SOLD
      supabaseAdmin
        .from("revenue")
        .select("id", { count: "exact", head: true })
        .eq("item_type", "book"),

      // REVENUE MTD
      supabaseAdmin
        .from("revenue")
        .select("amount, created_at")
        .gte("created_at", firstDay.toISOString()),

      // REVENUE TREND (6 MONTHS)
      supabaseAdmin
        .from("revenue")
        .select("amount, created_at")
        .gte("created_at", sixMonthsAgo.toISOString()),

      // RECENT ACTIVITY
      supabaseAdmin
        .from("activity_log")
        .select("*", { count: "exact" })
        .neq("type", "login")
        .order("created_at", { ascending: false })
        .range(start, end),
    ]);

    /* ======================================================
       USERS
    ====================================================== */
    if (customersRes.error) {
      console.error("v_customers error:", customersRes.error);
      return res.status(500).json({ error: "Failed to fetch user data" });
    }

    const customers = customersRes.data || [];
    const totalUsers = customers.length;

    /* ======================================================
       ACTIVE SUBSCRIPTIONS
    ====================================================== */
    const activeSubs = activeSubsRes.count || 0;

    /* ======================================================
       BOOKS SOLD
    ====================================================== */
    const booksSold = booksSoldRes.count || 0;

    /* ======================================================
       REVENUE MTD
    ====================================================== */
    const revenueMTD = Number(
      (
        revenueMonthRes.data?.reduce(
          (sum, r) => sum + Number(r.amount),
          0
        ) || 0
      ).toFixed(2)
    );

    /* ======================================================
       REVENUE TREND (GROUPED)
    ====================================================== */
    const revenueTrend = {};
    revenueTrendRes.data?.forEach((r) => {
      const m = formatMonth(r.created_at);
      revenueTrend[m] = (revenueTrend[m] || 0) + Number(r.amount);
    });

    /* ======================================================
       USER SIGNUP TREND
    ====================================================== */
    const recentUsers = customers.filter(
      (u) => u.created_at && new Date(u.created_at) >= sixMonthsAgo
    );

    const userTrend = {};
    recentUsers.forEach((u) => {
      const m = formatMonth(u.created_at);
      userTrend[m] = (userTrend[m] || 0) + 1;
    });

    /* ======================================================
       MERGE TRENDS FOR CHART
    ====================================================== */
    const monthOrder = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];

    const months = [
      ...new Set([...Object.keys(revenueTrend), ...Object.keys(userTrend)])
    ].sort((a, b) => monthOrder.indexOf(a) - monthOrder.indexOf(b));

    const chartData = months.map((m) => ({
      month: m,
      revenue: revenueTrend[m] || 0,
      users: userTrend[m] || 0,
    }));

    /* ======================================================
       KPI % CHANGE (UNCHANGED LOGIC)
    ====================================================== */
    const prevMonth =
      months.length >= 2 ? months[months.length - 2] : null;

    const prevUsers = userTrend[prevMonth] || 0;
    const prevRevenue = revenueTrend[prevMonth] || 0;

    const userGrowthPercent = percentChange(recentUsers.length, prevUsers);
    const revenueGrowthPercent = percentChange(revenueMTD, prevRevenue);

    const prevBooks = booksSold > 1 ? booksSold - 1 : 1;
    const prevSubs = activeSubs > 1 ? activeSubs - 1 : 1;

    const booksGrowthPercent = percentChange(booksSold, prevBooks);
    const subsGrowthPercent = percentChange(activeSubs, prevSubs);

    /* ======================================================
       ACTIVITY PAGINATION
    ====================================================== */
    const activities = activityRes.data || [];
    const totalPages = Math.ceil((activityRes.count || 0) / limit);

    /* ======================================================
       RESPONSE (IDENTICAL SHAPE)
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
      recentActivity: activities,
      activityPagination: {
        page,
        totalPages,
        total: activityRes.count || 0,
      },
    });

  } catch (err) {
    console.error("Dashboard error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};
