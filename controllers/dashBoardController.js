import supabase from "../utils/supabaseClient.js";

/**
 * 📊 GET /api/dashboard
 * Fetch complete dashboard data for a student
 */
export async function getDashboardData(req, res) {
  try {
    console.log("USER INSIDE BACKEND:", req.user);

    const userId = req.user.id || req.user.user_metadata?.app_user_id;

    /* --------------------
        1️⃣ Books Completed
    -------------------- */
    console.log("STEP 1: Fetch books completed");
    const { count: booksRead, error: booksError } = await supabase
      .from("user_books")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("status", "completed");

    if (booksError) throw booksError;

    // Last 30 days
    const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

    console.log("STEP 2: Fetch books completed this month");
    const { count: booksCompletedMonth, error: monthlyBooksError } =
      await supabase
        .from("user_books")
        .select("*", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("status", "completed")
        .gte("updated_at", thirtyDaysAgo);

    if (monthlyBooksError) throw monthlyBooksError;

    /* -------------------
        2️⃣ Tests completed
    --------------------- */
    console.log("STEP 3: Fetch test results");
    const { data: testResults, count: testsCompleted, error: testsError } =
      await supabase
        .from("test_results")
        .select("*", { count: "exact" })
        .eq("user_id", userId);

    if (testsError) throw testsError;

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
    console.log("STEP 4: Fetch study sessions");
    const { data: studyData, error: studyError } = await supabase
      .from("study_sessions")
      .select("duration, created_at")
      .eq("user_id", userId);

    if (studyError) throw studyError;

    const totalStudyHours =
      studyData?.reduce((sum, s) => sum + (s.duration || 0), 0) || 0;

    const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();

    const weeklyHours =
      studyData
        ?.filter((s) => s.created_at >= weekAgo)
        ?.reduce((sum, s) => sum + (s.duration || 0), 0) || 0;

    /* -------------------
        4️⃣ Active Streak
    --------------------- */
    console.log("STEP 5: Fetch active streak");
    const { data: streakData, error: streakError } = await supabase
      .from("user_streaks")
      .select("streak_days")
      .eq("user_id", userId)
      .maybeSingle();

    if (streakError && streakError.code !== "PGRST116")
      throw streakError;

    const activeStreak = streakData?.streak_days || 0;

    /* -------------------
        5️⃣ Continue Reading
    --------------------- */
    console.log("STEP 6: Fetch user_library rows");
    const { data: userLibRows, error: userLibError } = await supabase
      .from("user_library")
      .select("book_id, progress, added_at")
      .eq("user_id", userId)
      .order("added_at", { ascending: false })
      .limit(3);

    if (userLibError) throw userLibError;

    console.log("STEP 6.1: Fetching books for user_library");
    const recentBooks = [];


for (const row of userLibRows || []) {

  // Skip bad or null values
  if (!row.book_id || typeof row.book_id !== "string") {
    console.warn("⚠ Skipping row with invalid book_id:", row);
    continue;
  }

  const { data: bookData, error: bookError } = await supabase
    .from("books")
    .select("id, title, author, cover_url, description")
    .eq("id", row.book_id)
    .maybeSingle();

  // Skip if book not found
  if (bookError || !bookData) {
    console.warn("⚠ Book not found for:", row.book_id);
    continue;
  }

  recentBooks.push({
    ...row,
    books: bookData,
  });
}

    /* -------------------
        6️⃣ User Info
    --------------------- */
    console.log("STEP 7: Fetch user profile");
    let { data: userData, error: userError } = await supabase
      .from("profiles")
      .select("full_name, email")
      .eq("id", userId)
      .maybeSingle();

    if (userError && userError.code !== "PGRST116")
      throw userError;

    /* Auto-create missing profile */
    if (!userData) {
      console.log("➡ No profile found. Creating new profile...");

      const { data: newProfile, error: upsertError } = await supabase
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

      if (upsertError) throw upsertError;

      userData = newProfile;
    }

    // FINAL RESPONSE:
    res.json({
      user: userData,
      stats: {
        booksRead: booksRead || 0,
        booksThisMonth: booksCompletedMonth || 0,
        testsCompleted: testsCompleted || 0,
        avgScore: parseFloat(avgScore),
        studyHours: Math.round(totalStudyHours),
        weeklyHours: Math.round(weeklyHours),
        activeStreak,
      },
      recentBooks,
      weeklyProgress: {
        books: booksCompletedMonth || 0,
        tests:
          testResults?.filter(
            (t) => new Date(t.created_at) >= new Date(weekAgo)
          ).length || 0,
        hours: Math.round(weeklyHours),
      },
    });
  } catch (err) {
    console.error("🔥 FULL DASHBOARD ERROR:", err);
    console.error("🔥 ERROR MESSAGE:", err.message);
    console.error("🔥 ERROR DETAILS:", err.details);
    console.error("🔥 ERROR HINT:", err.hint);
    console.error("🔥 ERROR CODE:", err.code);

    res.status(500).json({ error: "Failed to fetch dashboard data" });
  }
}
