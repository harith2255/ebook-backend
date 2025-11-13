import supabase from "../../utils/supabaseClient.js";

// FORMATTER → Month names for graph
const formatMonth = (date) =>
  new Date(date).toLocaleString("en-US", { month: "short" });

export const getAdminDashboard = async (req, res) => {
  try {
    // ✅ TOTAL USERS
    const { count: totalUsers } = await supabase
      .from("users_metadata")
      .select("*", { count: "exact", head: true });

    // ✅ ACTIVE SUBSCRIPTIONS
    const { count: activeSubs } = await supabase
      .from("subscriptions")
      .select("*", { count: "exact", head: true });

    // ✅ BOOKS SOLD
    const { count: booksSold } = await supabase
      .from("book_sales")
      .select("*", { count: "exact", head: true });

    // ✅ REVENUE (MTD)
    const firstDay = new Date();
    firstDay.setDate(1);

    const { data: revenueMonth } = await supabase
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", firstDay.toISOString());

    const revenueMTD =
      revenueMonth?.reduce((sum, row) => sum + Number(row.amount), 0) || 0;

    // ✅ REVENUE LAST 6 MONTHS
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const { data: revenueTrendRows } = await supabase
      .from("revenue")
      .select("amount, created_at")
      .gte("created_at", sixMonthsAgo.toISOString());

    const revenueTrend = {};
    revenueTrendRows?.forEach((r) => {
      const m = formatMonth(r.created_at);
      revenueTrend[m] = (revenueTrend[m] || 0) + Number(r.amount);
    });

    // ✅ USER GROWTH LAST 6 MONTHS
    const { data: userTrendRows } = await supabase
      .from("users_metadata")
      .select("created_at")
      .gte("created_at", sixMonthsAgo.toISOString());

    const userGrowth = {};
    userTrendRows?.forEach((u) => {
      const m = formatMonth(u.created_at);
      userGrowth[m] = (userGrowth[m] || 0) + 1;
    });

    // ✅ CATEGORY DISTRIBUTION (Pie Chart)
    const { data: categoryRows } = await supabase
      .from("book_sales")
      .select("category");

    const categoryDistribution = {};
    categoryRows?.forEach((row) => {
      categoryDistribution[row.category] =
        (categoryDistribution[row.category] || 0) + 1;
    });

    const categoryData = Object.keys(categoryDistribution).map((cat) => ({
      name: cat,
      value: categoryDistribution[cat],
    }));

    // ✅ RECENT ACTIVITY LIST
    const { data: recentActivity } = await supabase
      .from("activity_log")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(20);

    // ✅ SEND FINAL DATA
    return res.json({
      kpis: {
        totalUsers,
        activeSubs,
        booksSold,
        revenueMTD,
      },
      revenueTrend,
      userGrowth,
      categoryData,
      recentActivity,
    });
  } catch (error) {
    console.error("Dashboard error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};
