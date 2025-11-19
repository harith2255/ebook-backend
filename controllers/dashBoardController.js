import supabase from "../utils/supabaseClient.js";

/**
 * 📊 GET /api/dashboard
 * Fetch complete dashboard data for a student
 */
export async function getDashboardData(req, res) {
  try {
    const userId = req.user.id;

    /* --------------------
       1️⃣ Books Completed
    -------------------- */
    const { count: booksRead } = await supabase
      .from("user_books")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("status", "completed");

    // Books completed last 30 days
    const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

    const { count: booksCompletedMonth } = await supabase
      .from("user_books")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("status", "completed")
      .gte("updated_at", thirtyDaysAgo);

    /* -------------------
       2️⃣ Tests completed
    --------------------- */
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

    /* -------------------
       3️⃣ Study Hours
    --------------------- */
    const { data: studyData } = await supabase
      .from("study_sessions")
      .select("duration, created_at")
      .eq("user_id", userId);

    const totalStudyHours =
      studyData?.reduce((sum, s) => sum + (s.duration || 0), 0) || 0;

    // last 7 days
    const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();

    const weeklyHours =
      studyData
        ?.filter((s) => s.created_at >= weekAgo)
        ?.reduce((sum, s) => sum + (s.duration || 0), 0) || 0;

    /* -------------------
       4️⃣ Active Streak
    --------------------- */
    const { data: streakData } = await supabase
      .from("user_streaks")
      .select("streak_days")
      .eq("user_id", userId)
      .single();

    const activeStreak = streakData?.streak_days || 0;

    /* -------------------
       5️⃣ Continue Reading
    --------------------- */
   const { data: recentBooks } = await supabase
  .from("user_library")
  .select(`
      book_id,
      progress,
      added_at,
      books (
        title,
        author,
        cover_url
      )
  `)
  .eq("user_id", userId)
  .order("added_at", { ascending: false })
  .limit(3);

  } catch (err) {
    console.error("Dashboard fetch error:", err.message);
    res.status(500).json({ error: "Failed to fetch dashboard data" });
  }
}
