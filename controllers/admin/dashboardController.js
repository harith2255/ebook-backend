import { supabaseAdmin } from "../../utils/supabaseClient.js";

const formatMonth = (date) =>
  new Date(date).toLocaleString("en-US", { month: "short" });

function percentChange(current, previous) {
  current = Number(current) || 0;
  previous = Number(previous) || 0;
  if (previous === 0) return 0;
  return Number((((current - previous) / previous) * 100).toFixed(1));
}

export const getAdminDashboard = async (req, res) => {
  try {
    /* ---------------------------------------------
       USERS FROM v_customers  (FIXED)
    --------------------------------------------- */
    const { data: customers, error: custErr } = await supabaseAdmin
      .from("v_customers")
      .select("id, joined");

    if (custErr) {
      console.error("v_customers fetch error:", custErr);
      return res.status(500).json({ error: "Cannot load user count" });
    }

    const totalUsers = customers.length;

    const nowISO = new Date().toISOString();

    /* ---------------------------------------------
       ACTIVE SUBSCRIPTIONS
    --------------------------------------------- */
    const { count: activeSubs } = await supabaseAdmin
      .from("user_subscriptions")
      .select("*", { count: "exact", head: true })
      .eq("status", "active")
      .gte("expires_at", nowISO);

    /* ---------------------------------------------
       BOOKS SOLD
    --------------------------------------------- */
    const { count: booksSold } = await supabaseAdmin
      .from("book_sales")
      .select("*", { count: "exact", head: true });

    /* ---------------------------------------------
       REVENUE (MTD)
    --------------------------------------------- */
    const firstDay = new Date();
    firstDay.setDate(1);

    const { data: revenueMonth } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", firstDay.toISOString());

    const revenueMTD =
      revenueMonth?.reduce((sum, r) => sum + Number(r.amount), 0) || 0;

    /* ---------------------------------------------
       REVENUE TREND (LAST 6 MONTHS)
    --------------------------------------------- */
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const { data: revRows } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", sixMonthsAgo.toISOString());

    const revenueTrend = {};
    revRows?.forEach((r) => {
      const m = formatMonth(r.created_at);
      revenueTrend[m] = (revenueTrend[m] || 0) + Number(r.amount);
    });

    /* ---------------------------------------------
       USER SIGNUP TREND  (FROM v_customers)
    --------------------------------------------- */
    const recentCustomers = customers.filter(
      (u) => u.joined && new Date(u.joined) >= sixMonthsAgo
    );

    const userGrowthTrend = {};
    recentCustomers.forEach((u) => {
      const m = formatMonth(u.joined);
      userGrowthTrend[m] = (userGrowthTrend[m] || 0) + 1;
    });

    /* ---------------------------------------------
       MERGE TRENDS
    --------------------------------------------- */
    const months = [...new Set([
      ...Object.keys(revenueTrend),
      ...Object.keys(userGrowthTrend),
    ])];

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
      users: userGrowthTrend[m] || 0,
    }));

    /* ---------------------------------------------
       KPI % CHANGES
    --------------------------------------------- */
    const prevMonthKey =
      sortedMonths.length >= 2 ? sortedMonths[sortedMonths.length - 2] : null;

    const prevUsers = Number(userGrowthTrend[prevMonthKey] || 0);
    const prevRevenue = Number(revenueTrend[prevMonthKey] || 0);
    const prevBooks = booksSold > 1 ? booksSold - 1 : 1;
    const prevSubs = activeSubs > 1 ? activeSubs - 1 : 1;

    const userGrowthPercent = percentChange(recentCustomers.length, prevUsers);
    const revenueGrowthPercent = percentChange(revenueMTD, prevRevenue);
    const booksGrowthPercent = percentChange(booksSold, prevBooks);
    const subsGrowthPercent = percentChange(activeSubs, prevSubs);

/* -------------------------------------------------------
   RECENT ACTIVITY (Last 10 + Pagination Support)
------------------------------------------------------- */
const page = Number(req.query.activity_page) || 1;
const limit = 10;
const start = (page - 1) * limit;
const end = start + limit - 1;

const { data: recentActivity, count, error: actErr } = await supabaseAdmin
  .from("activity_log")
  .select("*", { count: "exact" })
  .order("created_at", { ascending: false })
  .range(start, end);

if (actErr) {
  console.error("activity_log error:", actErr);
}

const totalPages = Math.ceil((count || 0) / limit);



    /* ---------------------------------------------
       SEND RESPONSE
    --------------------------------------------- */
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
  activityPagination: {
    page,
    totalPages,
    total: count || 0
  }
});


  } catch (error) {
    console.error("Dashboard error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};
