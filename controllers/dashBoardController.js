import supabase from "../utils/supabaseClient.js";

/**
 * 📊 GET /api/dashboard
 * Fetch complete dashboard data for a student
 */
export async function getDashboardData(req, res) {
  try {
    const userId = req.user.id;

    // 1️⃣ Books read count
    const { count: booksRead } = await supabase
      .from("user_books")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("status", "completed");

    // 2️⃣ Tests completed
    const { data: testResults, count: testsCompleted } = await supabase
      .from("test_results")
      .select("*", { count: "exact" })
      .eq("user_id", userId);

    const avgScore =
      testResults?.length > 0
        ? (
            testResults.reduce((sum, t) => sum + (t.score || 0), 0) /
            testResults.length
          ).toFixed(1)
        : 0;

    // 3️⃣ Study hours (mock example: from test_results duration or user_activity)
    const { data: studyData } = await supabase
      .from("study_sessions")
      .select("duration")
      .eq("user_id", userId);

    const totalStudyHours =
      studyData?.reduce((sum, s) => sum + (s.duration || 0), 0) || 0;

    // 4️⃣ Active streak (mock: check consecutive login days)
    const { data: streakData } = await supabase
      .from("user_streaks")
      .select("streak_days")
      .eq("user_id", userId)
      .single();

    const activeStreak = streakData?.streak_days || 0;

    // 5️⃣ Continue Reading books (recent reading activity)
    const { data: recentBooks } = await supabase
      .from("user_books")
      .select("book_id, progress, books(title, author, cover_url)")
      .eq("user_id", userId)
      .order("updated_at", { ascending: false })
      .limit(3);

    // 6️⃣ Upcoming Tests (future scheduled)
    const { data: upcomingTests } = await supabase
      .from("mock_tests")
      .select("id, title, scheduled_date, total_questions")
      .gt("scheduled_date", new Date().toISOString())
      .order("scheduled_date", { ascending: true })
      .limit(3);

    // 7️⃣ Recent Activities (mix of reading, test, and purchase)
    const { data: activities } = await supabase
      .from("user_activity")
      .select("action, details, created_at, type")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(5);

    res.json({
      stats: {
        booksRead: booksRead || 0,
        testsCompleted: testsCompleted || 0,
        avgScore,
        studyHours: totalStudyHours,
        activeStreak,
      },
      recentBooks: recentBooks || [],
      upcomingTests: upcomingTests || [],
      recentActivity: activities || [],
    });
  } catch (err) {
    console.error("Dashboard fetch error:", err.message);
    res.status(500).json({ error: "Failed to fetch dashboard data" });
  }
}
