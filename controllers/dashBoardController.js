// controllers/dashboardController.js
import supabase from "../utils/supabaseClient.js";

/**
 * 📊 GET /api/dashboard
 * Fetch complete dashboard data for a student
 *
 * NOTE: Because `user_library` only has `added_at` and not `updated_at`,
 * we use `added_at` when filtering for "books completed this month".
 * This is a limitation — see the migration SQL below to add `completed_at`.
 */
export async function getDashboardData(req, res) {
  try {
    const userId = req.user?.id || req.user?.user_metadata?.app_user_id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized: Missing userId" });
    }

    // --------------------
    // 1) Books Completed (total)
    //    using user_library.progress === 100
    // --------------------
    const { count: booksReadCount, error: booksReadErr } = await supabase
      .from("user_library")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("progress", 100);

    if (booksReadErr) throw booksReadErr;

    // --------------------
    // 2) Books completed in last 30 days
    //    Because there is no updated_at/completed_at we will filter by added_at
    //    AND progress === 100. This is imperfect if users finish books added long ago.
    // --------------------
    const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

    const { count: booksCompletedMonthCount, error: booksMonthErr } =
      await supabase
        .from("user_library")
        .select("*", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("progress", 100)
        .gte("added_at", thirtyDaysAgo);

    if (booksMonthErr) throw booksMonthErr;

    // --------------------
    // 3) Tests completed & avg score
    // --------------------
    const { data: testResults = [], count: testsCompletedCount, error: testsErr } =
      await supabase
        .from("test_results")
        .select("*", { count: "exact" })
        .eq("user_id", userId);

    if (testsErr) throw testsErr;

    const avgScore =
      testResults.length > 0
        ? (
            testResults.reduce((sum, t) => sum + (Number(t.score) || 0), 0) /
            testResults.length
          ).toFixed(1)
        : 0;

    // --------------------
    // 4) Study Hours
    // --------------------
    const { data: studySessions = [], error: studyErr } = await supabase
      .from("study_sessions")
      .select("duration, created_at")
      .eq("user_id", userId);

    if (studyErr) throw studyErr;

    const totalStudyHours = Math.round(
      (studySessions.reduce((sum, s) => sum + (Number(s.duration) || 0), 0) || 0)
    );

    const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();

    const weeklyHours = Math.round(
      studySessions
        .filter((s) => s.created_at >= weekAgo)
        .reduce((sum, s) => sum + (Number(s.duration) || 0), 0) || 0
    );

    // --------------------
    // 5) Active Streak
    // --------------------
    const { data: streakData, error: streakErr } = await supabase
      .from("user_streaks")
      .select("streak_days")
      .eq("user_id", userId)
      .maybeSingle();

    if (streakErr && streakErr.code !== "PGRST116") throw streakErr;
    const activeStreak = streakData?.streak_days || 0;

    // --------------------
    // 6) Continue Reading (recent books) — include last_page & progress
    // --------------------
    const { data: recentBooksRaw = [], error: recentBooksErr } = await supabase
      .from("user_library")
      .select(`
        book_id,
        progress,
        last_page,
        added_at,
        ebooks (
          id,
          title,
          author,
          cover_url,
          description,
          file_url,
          pages
        )
      `)
      .eq("user_id", userId)
      .order("added_at", { ascending: false })
      .limit(5);

    if (recentBooksErr) throw recentBooksErr;

    const FALLBACK_COVER_PATH = "/mnt/data/397e2adf-175b-45d7-b8b0-a860b51d99a3.png";

    const recentBooks = (recentBooksRaw || []).map((row) => {
      const book = row?.ebooks || null;
      return {
        book_id: row.book_id,
        last_page: row.last_page || 1,
        progress: row.progress || 0,
        added_at: row.added_at,
        ebooks: {
          ...book,
          file_url: book?.file_url || null,
          cover_url: book?.cover_url || FALLBACK_COVER_PATH,
        },
      };
    });

    // --------------------
    // 7) User profile (basic)
    // --------------------
    let { data: userData, error: userErr } = await supabase
      .from("profiles")
      .select("full_name, email")
      .eq("id", userId)
      .maybeSingle();

    if (userErr && userErr.code !== "PGRST116") throw userErr;

    if (!userData) {
      // create a minimal profile if missing
      const { data: newProfile, error: upsertErr } = await supabase
        .from("profiles")
        .upsert({
          id: userId,
          email: req.user.email,
          full_name:
            req.user.user_metadata?.full_name ||
            req.user.email?.split("@")[0],
        })
        .select()
        .single();

      if (upsertErr) throw upsertErr;
      userData = newProfile;
    }

    // --------------------
    // Final assembled response
    // --------------------
    return res.json({
      user: userData,
      stats: {
        booksRead: booksReadCount || 0,
        booksThisMonth: booksCompletedMonthCount || 0,
        testsCompleted: testsCompletedCount || 0,
        avgScore: parseFloat(avgScore) || 0,
        studyHours: totalStudyHours || 0,
        weeklyHours: weeklyHours || 0,
        activeStreak: activeStreak || 0,
      },
      recentBooks,
      weeklyProgress: {
        books: booksCompletedMonthCount || 0,
        tests:
          testResults?.filter(
            (t) => new Date(t.created_at) >= new Date(weekAgo)
          ).length || 0,
        hours: weeklyHours || 0,
      },
    });
  } catch (err) {
    console.error("🔥 DASHBOARD ERROR:", err);
    return res.status(500).json({ error: "Failed to fetch dashboard data" });
  }
}
