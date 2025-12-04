import supabase from "../utils/supabaseClient.js";

/* ======================================================
   GET AVAILABLE + UPCOMING TESTS
====================================================== */
export const getAvailableTests = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("mock_tests")
      .select(`
        id,
        title,
        subject,
        difficulty,
        duration_minutes,
        total_questions,
        participants,
        start_time
      `)
      .order("start_time", { ascending: true });

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data || []);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch tests" });
  }
};


/* ======================================================
   GET TEST DETAILS
====================================================== */
export const getTestDetails = async (req, res) => {
  const id = Number(req.params.id);

  if (!id) return res.status(400).json({ error: "Invalid test id" });

  try {
    const { data, error } = await supabase
      .from("mock_tests")
      .select(`
        id,
        title,
        subject,
        difficulty,
        total_questions,
        duration_minutes,
        start_time,
        end_time,
        scheduled_date,
        description,
        status
      `)
      .eq("id", id)
      .maybeSingle();

    if (error && error.code !== "PGRST116") {
      return res.status(400).json({ error: error.message });
    }

    if (!data) {
      return res.status(404).json({ error: "Test not found" });
    }

    const { data: questions } = await supabase
      .from("mock_test_questions")
      .select(`
        id,
        question,
        option_a,
        option_b,
        option_c,
        option_d,
        correct_option
      `)
      .eq("test_id", id)
      .order("id");

    return res.json({
      ...data,
      mock_test_questions: questions || [],
    });
  } catch (err) {
    console.error("getTestDetails crash:", err);
    return res.status(500).json({ error: "Server error" });
  }
};


/* ======================================================
   ONGOING TESTS FOR USER
====================================================== */
export const getOngoingTests = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.json([]);

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

    // Remove attempts without real tests
    const clean = (data || []).filter(a => a.mock_tests);

    return res.json(clean);
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
    const userId = req.user?.id;
    if (!userId) return res.json([]);

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

    const clean = (data || []).filter(a => a.mock_tests);

    return res.json(clean);
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
    const currentUserId = req.user?.id || null;

    const { data: board, error } = await supabase
      .from("mock_leaderboard")
      .select("user_id, average_score, tests_taken")
      .order("average_score", { ascending: false })
      .limit(50);

    if (error) return res.status(400).json({ error: error.message });
    if (!board?.length) return res.json([]);

    const userIds = board.map(x => x.user_id);

    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, full_name, first_name, last_name, status")
      .in("id", userIds);

    const map = Object.fromEntries((profiles || []).map(p => [p.id, p]));

    const filtered = board
      .map(user => {
        const p = map[user.user_id] || {};

        const name =
          p.full_name?.trim() ||
          `${p.first_name || ""} ${p.last_name || ""}`.trim() ||
          null;

        return {
          user_id: user.user_id,
          display_name: name,
          average_score: user.average_score || 0,
          tests_taken: user.tests_taken || 0,
          status: p.status?.toLowerCase() || "active",
        };
      })
      .filter(u => {
        if (!u.display_name) return false;
        if (["inactive", "banned"].includes(u.status)) return false;
        if (u.tests_taken <= 0 && u.user_id !== currentUserId) return false;
        return true;
      });

    filtered.sort((a, b) => b.average_score - a.average_score);

    const ranked = filtered.map((u, i) => ({
      ...u,
      rank: i + 1,
    }));

    return res.json(ranked);
  } catch (err) {
    console.error("getLeaderboard crash:", err);
    return res.status(500).json({ error: "Failed to fetch leaderboard" });
  }
};


/* ======================================================
   USER STATS (SMART AGGREGATE)
====================================================== */
export const getStats = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.json({
        tests_taken: 0,
        average_score: 0,
        best_rank: null,
        total_study_time: 0,
      });
    }

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

    const scores = data.map(x => Number(x.score) || 0);
    const ranks = data.map(x => x.rank).filter(r => typeof r === "number");
    const time = data.map(x => Number(x.time_spent) || 0);

    const tests_taken = data.length;
    const average_score = Math.round(scores.reduce((a, b) => a + b, 0) / tests_taken);
    const best_rank = ranks.length ? Math.min(...ranks) : null;
    const total_study_time = time.reduce((a, b) => a + b, 0);

    return res.json({
      tests_taken,
      average_score,
      best_rank,
      total_study_time,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to fetch stats" });
  }
};
