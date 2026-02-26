// controllers/dashboardController.js
import supabase from "../utils/pgClient.js";

// Ignore sessions shorter than ~1 minute
const MIN_SESSION_HOURS = 1 / 60; // 0.0167 hours


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
 const { data: completedTests = [], error: testsErr } = await supabase
  .from("mock_attempts")
  .select("score, completed_at")
  .eq("user_id", userId)
  .eq("status", "completed");

if (testsErr) throw testsErr;

const testsCompletedCount = completedTests.length;

const avgScore =
  testsCompletedCount > 0
    ? Number(
        (
          completedTests.reduce(
            (sum, t) => sum + (Number(t.score) || 0),
            0
          ) / testsCompletedCount
        ).toFixed(1)
      )
    : 0;

// weekly tests (last 7 days)
const weekAgo = new Date(Date.now() - 7 * 86400000);

const weeklyTests = completedTests.filter(
  (t) => new Date(t.completed_at) >= weekAgo
).length;

    // --------------------
    // 4) Study Hours
    // --------------------
    const { data: studySessions = [], error: studyErr } = await supabase
  .from("study_sessions")
  .select("duration, created_at")
  .eq("user_id", userId);

if (studyErr) throw studyErr;

// TOTAL HOURS (keep decimals)
// TOTAL HOURS — accurate & stable
const totalStudyHoursRaw = studySessions
  .filter(s => Number(s.duration) >= MIN_SESSION_HOURS)
  .reduce((sum, s) => sum + Number(s.duration), 0);

const totalStudyHours = Math.round(totalStudyHoursRaw * 10) / 10;


// WEEKLY HOURS
const weekAgoDate = new Date(Date.now() - 7 * 86400000);

const weeklyHoursRaw = studySessions
  .filter(
    s =>
      Number(s.duration) >= MIN_SESSION_HOURS &&
      new Date(s.created_at) >= weekAgoDate
  )
  .reduce((sum, s) => sum + Number(s.duration), 0);

const weeklyHours = Math.round(weeklyHoursRaw * 10) / 10;


    // --------------------
    // 5) Active Streak (dynamic from study_sessions)
    // --------------------
    const { data: userSessions, error: activityErr } = await supabase
      .from("study_sessions")
      .select("created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (activityErr) throw activityErr;

    // Extract unique dates as YYYY-MM-DD strings
    const activityDates = [...new Set(
      (userSessions || []).map(s => new Date(s.created_at).toISOString().split('T')[0])
    )];

    let streak = 0;
    
    // We check backwards from today
    let checkDate = new Date();
    
    // First, check if the user was active today. If not, check yesterday.
    // If not active yesterday, streak is automatically 0.
    const todayStr = checkDate.toISOString().split('T')[0];
    
    checkDate.setDate(checkDate.getDate() - 1);
    const yesterdayStr = checkDate.toISOString().split('T')[0];

    // Build normalized array
    let streakDate = new Date();
    
    if (activityDates.includes(todayStr)) {
       // active today, streak continues
    } else if (activityDates.includes(yesterdayStr)) {
       // active yesterday but not today, streak continues but start checking from yesterday
       streakDate.setDate(streakDate.getDate() - 1);
    } else {
       // inactive for >2 days, streak is 0
       activityDates.length = 0; 
    }

    // Count backwards from streakDate
    while (activityDates.includes(streakDate.toISOString().split('T')[0])) {
      streak++;
      streakDate.setDate(streakDate.getDate() - 1);
    }

    const activeStreak = streak;


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
  userData = {
    full_name: req.user.user_metadata?.full_name || "User",
    email: req.user.email,
  };
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
    tests: weeklyTests || 0,
    hours: weeklyHours || 0,
  },
});

  } catch (err) {
    console.error("🔥 DASHBOARD ERROR:", err);
    return res.status(500).json({ error: "Failed to fetch dashboard data" });
  }
}
