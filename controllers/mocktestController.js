import supabase from "../utils/supabaseClient.js";

export const getAvailableTests = async (req, res) => {
  const { data, error } = await supabase
    .from("mock_tests")
    .select("*, mcqs")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

export const getTestDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from("mock_tests")
      .select("id, title, subject, duration_minutes, total_questions, mcqs")
      .eq("id", id)
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    return res.json(data);

  } catch (err) {
    return res.status(500).json({ error: "Failed to load test details" });
  }
};



export const getOngoingTests = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select(`
      id,
      test_id,
      completed_questions,
      mock_tests (*)
    `)
    .eq("user_id", userId)
    .eq("status", "ongoing");

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};

export const getCompletedTests = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select(`
      id,
      test_id,
      score,
      rank,
      completed_at,
      mock_tests(*)
    `)
    .eq("user_id", userId)
    .eq("status", "completed");

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};

export const getLeaderboard = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("mock_leaderboard")
      .select("user_id, display_name, average_score, tests_taken")
      .order("average_score", { ascending: false });

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    return res.json(data);

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};



export const getStats = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select("score, rank, time_spent")
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });

  const testsTaken = data.length;
  const avgScore = data.length ? (data.reduce((a, b) => a + b.score, 0) / data.length) : 0;
  const bestRank = data.length ? Math.min(...data.map(x => x.rank ?? 9999)) : null;
  const totalStudyTime = data.reduce((a, b) => a + (b.time_spent || 0), 0);

  res.json({
    tests_taken: testsTaken,
    average_score: Math.round(avgScore),
    best_rank: bestRank,
    total_study_time: totalStudyTime
  });
};
export const startTest = async (req, res) => {
  try {
    const { test_id } = req.body;
    const user_id = req.user.id;

    if (!test_id) return res.status(400).json({ error: "Missing test_id" });

    // fetch test with mcqs
    const { data: test, error: testErr } = await supabase
      .from("mock_tests")
      .select("*, mcqs")
      .eq("id", test_id)
      .single();

    if (testErr) return res.status(400).json({ error: testErr.message });

    // create attempt
    const { data: attempt, error: err1 } = await supabase
      .from("mock_attempts")
      .insert({
        user_id,
        test_id,
        status: "ongoing",
        started_at: new Date(),
        completed_questions: 0,
        score: 0
      })
      .select()
      .single();

    if (err1) return res.status(400).json({ error: err1.message });

    // increment participants
    await supabase.rpc("increment_participants", { testid: test_id });

    return res.json({ attempt, test }); // <-- RETURN QUESTIONS
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

