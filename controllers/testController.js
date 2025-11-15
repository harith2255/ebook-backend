import supabase from "../utils/supabaseClient.js";

/* ============================================
   START TEST
============================================ */
export const startTest = async (req, res) => {
  try {
    const { test_id } = req.body;
    const user_id = req.user.id;

    if (!test_id) {
      return res.status(400).json({ error: "Missing test_id" });
    }

    const { data: attempt, error } = await supabase
      .from("mock_attempts")
      .insert({
        user_id,
        test_id,
        status: "in_progress",   // ✔ matches DB CHECK
        started_at: new Date(),
        completed_questions: 0,
        score: 0,
        time_spent: 0
      })
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ attempt });

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};

/* ============================================
   GET QUESTIONS
   (This is where your problem was)
============================================ */
export const getQuestions = async (req, res) => {
  try {
    const { test_id } = req.params;

    const { data, error } = await supabase
      .from("mock_test_questions")   // ✔ correct table
      .select("*")
      .eq("test_id", test_id)
      .order("id");

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data);

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};

/* ============================================
   SAVE ANSWER
============================================ */
export const saveAnswer = async (req, res) => {
  const { attempt_id, question_id, answer } = req.body;

  // 1️⃣ Save or update user's answer
  await supabase
    .from("mock_answers")
    .upsert({
      attempt_id,
      question_id,
      answer
    });

  // 2️⃣ Count completed answers
  const { count } = await supabase
    .from("mock_answers")
    .select("*", { count: "exact", head: true })
    .eq("attempt_id", attempt_id);

  // 3️⃣ Update mock_attempts progress
  await supabase
    .from("mock_attempts")
    .update({ completed_questions: count })
    .eq("id", attempt_id);

  return res.json({ success: true });
};


/* ============================================
   FINISH TEST
============================================ */
export const finishTest = async (req, res) => {
  try {
    const { attempt_id } = req.body;
    const user_id = req.user.id;

    const { data: attempt } = await supabase
      .from("mock_attempts")
      .select("test_id, started_at")
      .eq("id", attempt_id)
      .single();

    const { score, percentScore } = await calculateScore(
      attempt_id,
      attempt.test_id
    );

    const started = new Date(attempt.started_at);
    const now = new Date();
    const timeSpent = Math.round((now - started) / 1000 / 60);

    // 1️⃣ Update attempt
    await supabase
      .from("mock_attempts")
      .update({
        status: "completed",
        score: percentScore,
        completed_at: now,
        time_spent: timeSpent
      })
      .eq("id", attempt_id);

    // 2️⃣ Update participants count
    await supabase.rpc("increment_participants", {
      test_id_input: attempt.test_id
    });

    // 3️⃣ Update leaderboard & stats
    await updateLeaderboard(user_id);
    await updateUserStats(user_id, percentScore, timeSpent);

    // 4️⃣ Update ranks
    await updateRanks();

    res.json({ success: true });
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: err.message });
  }
};


/* ============================================
   CHECK ATTEMPT STATUS
============================================ */
export const getAttemptStatus = async (req, res) => {
  try {
    const { attempt_id } = req.params;

    const { data, error } = await supabase
      .from("mock_attempts")
      .select("*")
      .eq("id", attempt_id)
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data);

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
// Calculate score for an attempt
async function calculateScore(attempt_id, test_id) {
  // Get all questions & correct answers
  const { data: questions } = await supabase
    .from("mock_test_questions")
    .select("id, correct_option")
    .eq("test_id", test_id);

  // Get all saved answers
  const { data: answers } = await supabase
    .from("mock_answers")
    .select("question_id, answer")
    .eq("attempt_id", attempt_id);

  let score = 0;

  questions.forEach(q => {
    const userAns = answers.find(a => a.question_id === q.id);
    if (userAns && userAns.answer === q.correct_option) {
      score++;
    }
  });

  // percentage
  const percentScore = (score / questions.length) * 100;

  return { score, percentScore };
}
async function updateLeaderboard(user_id) {
  const { data, error } = await supabase
    .from("mock_attempts")
    .select("score")
    .eq("user_id", user_id)
    .eq("status", "completed");

  const scores = data.map(s => s.score);
  const avg = scores.length ? scores.reduce((a,b) => a + b, 0) / scores.length : 0;

  await supabase
    .from("mock_leaderboard")
    .upsert({
      user_id,
      average_score: avg,
      tests_taken: scores.length
    });
}

async function updateUserStats(user_id, newScore, timeSpent) {
  const { data: stats } = await supabase
    .from("user_stats")
    .select("*")
    .eq("user_id", user_id)
    .single();

  if (!stats) {
    await supabase.from("user_stats").insert({
      user_id,
      tests_taken: 1,
      average_score: newScore,
      best_rank: null,
      total_study_time: timeSpent
    });
    return;
  }

  const totalTests = stats.tests_taken + 1;
  const avgScore =
    (stats.average_score * stats.tests_taken + newScore) / totalTests;

  await supabase
    .from("user_stats")
    .update({
      tests_taken: totalTests,
      average_score: avgScore,
      total_study_time: stats.total_study_time + timeSpent
    })
    .eq("user_id", user_id);
}
async function updateRanks() {
  // Fetch all leaderboard entries sorted by score DESC
  const { data: leaderboard } = await supabase
    .from("mock_leaderboard")
    .select("user_id, average_score")
    .order("average_score", { ascending: false });

  if (!leaderboard || leaderboard.length === 0) return;

  // Assign ranks
  for (let i = 0; i < leaderboard.length; i++) {
    const rank = i + 1;
    const user_id = leaderboard[i].user_id;

    // Update leaderboard best_rank
    await supabase
      .from("mock_leaderboard")
      .update({ best_rank: rank })
      .eq("user_id", user_id);

    // Update all attempts for this user
    await supabase
      .from("mock_attempts")
      .update({ rank })
      .eq("user_id", user_id)
      .eq("status", "completed");
  }
}
