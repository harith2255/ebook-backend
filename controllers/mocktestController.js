import supabase from "../utils/supabaseClient.js";

/* ======================================================
   GET AVAILABLE + UPCOMING TESTS
====================================================== */
export const getAvailableTests = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("mock_tests")
      .select("id, title, subject, difficulty, duration_minutes, total_questions, participants, start_time")
      .order("start_time", { ascending: true });

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data ?? []);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch tests" });
  }
};


/* ======================================================
   GET TEST DETAILS
====================================================== */
export const getTestDetails = async (req, res) => {
  try {
    const { id } = req.params;

    // get test metadata
    const { data: test, error: testErr } = await supabase
      .from("mock_tests")
      .select("id, title, subject, duration_minutes, total_questions, start_time")
      .eq("id", id)
      .single();

    if (testErr || !test) {
      return res.status(404).json({ error: "Test not found" });
    }

    // fetch questions
    const { data: mcqs, error: qErr } = await supabase
      .from("mock_test_questions")
      .select("id, question, option_a, option_b, option_c, option_d, correct_option")
      .eq("test_id", id)
      .order("id");

    if (qErr) {
      return res.status(400).json({ error: qErr.message });
    }

    // attach to test
    test.mcqs = mcqs || [];

    return res.json(test);

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to load test details" });
  }
};




/* ======================================================
   ONGOING TESTS FOR USER
====================================================== */
export const getOngoingTests = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("mock_attempts")
      .select(`
        id,
        test_id,
        completed_questions,
        mock_tests (
          title,
          subject,
          difficulty,
          duration_minutes,
          total_questions,
          participants
        )
      `)
      .eq("user_id", userId)
      .eq("status", "in_progress");

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data ?? []);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch ongoing tests" });
  }
};



/* ======================================================
   COMPLETED TESTS FOR USER
====================================================== */
export const getCompletedTests = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("mock_attempts")
      .select(`
        id,
        test_id,
        score,
        rank,
        time_spent,
        completed_at,
        mock_tests (
          title,
          subject,
          duration_minutes,
          participants
        )
      `)
      .eq("user_id", userId)
      .eq("status", "completed")
      .order("completed_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data ?? []);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch completed tests" });
  }
};



/* ======================================================
   LEADERBOARD
====================================================== */
export const getLeaderboard = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("mock_leaderboard")
      .select(`
        user_id,
        display_name,
        average_score,
        tests_taken
      `)
      .order("average_score", { ascending: false })
      .limit(50);

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data ?? []);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch leaderboard" });
  }
};


/* ======================================================
   USER STATS (SMART AGGREGATE)
====================================================== */
export const getStats = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("mock_attempts")
      .select("score, rank, time_spent")
      .eq("user_id", userId)
      .eq("status", "completed");

    if (error) return res.status(400).json({ error: error.message });

    if (!data?.length) {
      return res.json({
        tests_taken: 0,
        average_score: 0,
        best_rank: null,
        total_study_time: 0,
      });
    }

    const scores = data.map(x => x.score || 0);
    const ranks = data.map(x => x.rank).filter(Boolean);
    const time = data.map(x => x.time_spent || 0);

    const tests_taken = data.length;
    const average_score = Math.round(scores.reduce((a, b) => a + b, 0) / tests_taken);
    const best_rank = ranks.length ? Math.min(...ranks) : null;
    const total_study_time = time.reduce((a, b) => a + b, 0);

    return res.json({
      tests_taken,
      average_score,
      best_rank,
      total_study_time
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch stats" });
  }
};
