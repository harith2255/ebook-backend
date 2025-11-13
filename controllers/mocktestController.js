// controllers/mocktestController.js
import supabase from "../utils/supabaseClient.js";

/* ----------------------------------------------------
   📌 1. ALL AVAILABLE MOCK TESTS
-----------------------------------------------------*/
export const getAllMockTests = async (req, res) => {
  const { data, error } = await supabase
    .from("mock_tests")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ----------------------------------------------------
   📌 2. START MOCK TEST (creates attempt)
-----------------------------------------------------*/
export const startMockTest = async (req, res) => {
  const userId = req.user.id;
  const { test_id } = req.body;

  if (!test_id) return res.status(400).json({ error: "test_id required" });

  // If already in progress
  const { data: existing } = await supabase
    .from("mock_attempts")
    .select("*")
    .eq("user_id", userId)
    .eq("test_id", test_id)
    .eq("status", "in_progress")
    .maybeSingle();

  if (existing) {
    return res.json({ message: "Already in progress", attempt: existing });
  }

  // New attempt
  const { data, error } = await supabase
    .from("mock_attempts")
    .insert([{ user_id: userId, test_id, status: "in_progress" }])
    .select();

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Test started", attempt: data[0] });
};

/* ----------------------------------------------------
   📌 3. ONGOING TESTS
-----------------------------------------------------*/
export const getOngoingTests = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select(`
      id,
      test_id,
      status,
      score,
      started_at,
      mock_tests:mock_tests!mock_attempts_test_id_fkey (
        id,
        title,
        subject,
        total_questions,
        duration_minutes,
        difficulty
      )
    `)
    .eq("user_id", userId)
    .eq("status", "in_progress");

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};


/* ----------------------------------------------------
   📌 4. COMPLETED TESTS
-----------------------------------------------------*/
export const getCompletedTests = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select(`
      id,
      test_id,
      score,
      completed_at,
      status,
      mock_tests:mock_tests!mock_attempts_test_id_fkey (
        id,
        title,
        subject,
        total_questions,
        duration_minutes,
        difficulty
      )
    `)
    .eq("user_id", userId)
    .in("status", ["completed", "time_expired"]);

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};


/* ----------------------------------------------------
   📌 5. GET USER STATS (dashboard)
-----------------------------------------------------*/
export const getUserStats = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_stats")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) return res.status(400).json({ error: error.message });

  res.json(
    data || {
      tests_taken: 0,
      average_score: 0,
      best_rank: null,
      total_study_time: 0,
    }
  );
};

/* ----------------------------------------------------
   📌 6. UPDATE USER STATS (called after finishTest)
-----------------------------------------------------*/
export const updateUserStats = async (userId) => {
  try {
    const { data: attempts } = await supabase
      .from("mock_attempts")
      .select("score, rank, time_spent")
      .eq("user_id", userId)
      .eq("status", "completed");

    if (!attempts?.length) return;

    const tests_taken = attempts.length;

    const average_score = Math.round(
      attempts.reduce((x, a) => x + (a.score || 0), 0) / tests_taken
    );

    const best_rank = Math.min(
      ...attempts.map((a) => a.rank || Infinity)
    );

    const total_study_time = attempts.reduce(
      (x, a) => x + (a.time_spent || 0),
      0
    );

    await supabase.from("user_stats").upsert(
      {
        user_id: userId,
        tests_taken,
        average_score,
        best_rank: best_rank === Infinity ? null : best_rank,
        total_study_time,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );

  } catch (e) {
    console.error("Failed to update stats:", e.message);
  }
};

/* ----------------------------------------------------
   📌 7. LEADERBOARD
-----------------------------------------------------*/
export const getLeaderboard = async (req, res) => {
  const { data, error } = await supabase
    .from("user_stats")
    .select("user_id, average_score, tests_taken, best_rank")
    .order("average_score", { ascending: false })
    .limit(20);

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};
