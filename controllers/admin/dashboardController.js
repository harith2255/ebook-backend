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
       REAL USERS (FROM PROFILES — ALWAYS ACCURATE)
       🔧 FIX: Use supabaseAdmin instead of supabase
    --------------------------------------------- */
    const { data: profiles, error: profErr } = await supabaseAdmin
      .from("profiles")
      .select("id, created_at");

    if (profErr) {
      console.error("Profiles fetch error:", profErr);
      return res.status(500).json({ error: "Cannot load user count" });
    }

    const totalUsers = profiles.length;

    /* -------------------------------------------------------
       ACTIVE SUBSCRIPTIONS
       🔧 FIX: Use supabaseAdmin
    ------------------------------------------------------- */
    const nowISO = new Date().toISOString();

    const { count: activeSubs } = await supabaseAdmin
      .from("user_subscriptions")
      .select("*", { count: "exact", head: true })
      .eq("status", "active")
      .gte("expires_at", nowISO);

    /* -------------------------------------------------------
       BOOKS SOLD
       🔧 FIX: Use supabaseAdmin
    ------------------------------------------------------- */
    const { count: booksSold } = await supabaseAdmin
      .from("book_sales")
      .select("*", { count: "exact", head: true });

    /* -------------------------------------------------------
       REVENUE (MTD)
       🔧 FIX: Use supabaseAdmin
    ------------------------------------------------------- */
    const firstDay = new Date();
    firstDay.setDate(1);

    const { data: revenueMonth } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", firstDay.toISOString());

    const revenueMTD =
      revenueMonth?.reduce((s, r) => s + Number(r.amount), 0) || 0;

    /* -------------------------------------------------------
       REVENUE TREND (LAST 6 MONTHS)
       🔧 FIX: Use supabaseAdmin
    ------------------------------------------------------- */
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

    /* -------------------------------------------------------
       USER SIGNUPS TREND (FROM PROFILES)
    ------------------------------------------------------- */
    const recentProfiles = profiles.filter(
      (p) => p.created_at && new Date(p.created_at) >= sixMonthsAgo
    );

    const userGrowthTrend = {};

    recentProfiles.forEach((u) => {
      const m = formatMonth(u.created_at);
      userGrowthTrend[m] = (userGrowthTrend[m] || 0) + 1;
    });

    /* -------------------------------------------------------
       COMBINE TRENDS
    ------------------------------------------------------- */
    const months = [
      ...new Set([
        ...Object.keys(revenueTrend),
        ...Object.keys(userGrowthTrend),
      ]),
    ];

    const monthOrder = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
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
       KPI PERCENTAGES
    ------------------------------------------------------- */
    const prevMonthKey =
      sortedMonths.length >= 2
        ? sortedMonths[sortedMonths.length - 2]
        : null;

    const prevUsers = Number(userGrowthTrend[prevMonthKey] || 0);
    const prevRevenue = Number(revenueTrend[prevMonthKey] || 0);
    const prevBooks = booksSold > 1 ? booksSold - 1 : 1;
    const prevSubs = activeSubs > 1 ? activeSubs - 1 : 1;

    const userGrowthPercent = percentChange(recentProfiles.length, prevUsers);
    const revenueGrowthPercent = percentChange(revenueMTD, prevRevenue);
    const booksGrowthPercent = percentChange(booksSold, prevBooks);
    const subsGrowthPercent = percentChange(activeSubs, prevSubs);

    /* -------------------------------------------------------
       RECENT ACTIVITY
       🔧 FIX: Use supabaseAdmin
    ------------------------------------------------------- */
    const { data: recentActivity } = await supabaseAdmin
      .from("activity_log")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(20);

    /* -------------------------------------------------------
       SEND RESPONSE
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