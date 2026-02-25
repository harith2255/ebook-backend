import supabase from "../utils/supabaseClient.js";
import pool from "../utils/db.js";

/* ======================================================
   GET AVAILABLE + UPCOMING TESTS
====================================================== */
export const getAvailableTests = async (req, res) => {
  try {
    const { rows: data } = await pool.query(`
      SELECT 
        m.id, m.title, m.subject, m.difficulty, 
        m.duration_minutes, m.total_questions, m.start_time,
        COALESCE(
          json_agg(json_build_object('user_id', a.user_id)) 
          FILTER (WHERE a.id IS NOT NULL), '[]'
        ) as mock_attempts
      FROM mock_tests m
      LEFT JOIN mock_attempts a ON m.id = a.test_id
      GROUP BY m.id
      ORDER BY m.start_time ASC
    `);

    const result = data.map(t => ({
      id: t.id,
      title: t.title,
      subject: t.subject,
      difficulty: t.difficulty,
      duration_minutes: t.duration_minutes,
      total_questions: t.total_questions,
      start_time: t.start_time,
      participants: new Set(
        (t.mock_attempts || []).map(a => a.user_id)
      ).size,
    }));

    return res.json(result);
  } catch (err) {
    console.error("getAvailableTests error:", err);
    return res.status(500).json({ error: "Failed to fetch tests", msg: err.message || JSON.stringify(err) });
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
  percentile,
  completed_at,
  mock_tests (
    title,
    subject,
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
      .select(`
        score,
        rank,
        time_spent,
        mock_tests!inner(id)
      `)
      .eq("user_id", userId)
      .eq("status", "completed");

    if (error || !data?.length) {
      return res.json({
        tests_taken: 0,
        average_score: 0,
        best_rank: null,
        total_study_time: 0,
      });
    }

    const tests_taken = data.length;

    const average_score = Math.round(
      data.reduce((s, a) => s + (a.score || 0), 0) / tests_taken
    );

    const best_rank =
      Math.min(...data.map(a => a.rank).filter(r => typeof r === "number")) ||
      null;

    const total_study_time = data.reduce(
      (s, a) => s + (a.time_spent || 0),
      0
    );

    return res.json({
      tests_taken,
      average_score,
      best_rank,
      total_study_time,
    });
  } catch (err) {
    console.error("getStats error:", err);
    return res.status(500).json({ error: "Failed to fetch stats" });
  }
};

