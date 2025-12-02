import supabase from "../utils/supabaseClient.js";

/* ==========================================================
   START TEST
========================================================== */
export const startTest = async (req, res) => {
  try {
    const { test_id } = req.body;
    const user_id = req.user.id;

    if (!test_id) {
      return res.status(400).json({ error: "Missing test_id" });
    }

    /* 1️⃣ Check test exists */
    const { data: test, error: testErr } = await supabase
      .from("mock_tests")
      .select("id, start_time")
      .eq("id", test_id)
      .single();

    if (testErr || !test) {
      return res.status(404).json({ error: "Test not found" });
    }

    /* 2️⃣ Prevent starting before start_time */
    if (test.start_time && new Date(test.start_time) > new Date()) {
      return res.status(400).json({ error: "This test has not started yet" });
    }

    /* 3️⃣ Check if user already has ongoing attempt */
    const { data: existing } = await supabase
      .from("mock_attempts")
      .select("id")
      .eq("user_id", user_id)
      .eq("test_id", test_id)
      .eq("status", "in_progress")
      .maybeSingle();

    if (existing) {
      return res.json({
        attempt: existing,
        already_started: true,
      });
    }

    /* 4️⃣ Create new attempt */
    const { data: attempt, error: insertErr } = await supabase
      .from("mock_attempts")
      .insert({
        user_id,
        test_id,
        status: "in_progress",
        started_at: new Date(),
        completed_questions: 0,
        score: 0,
        time_spent: 0,
      })
      .select()
      .single();

    if (insertErr) {
      return res.status(400).json({ error: insertErr.message });
    }

    /* 5️⃣ Increment participant count (async, non-blocking) */
   try {
  const { error } = await supabase.rpc("increment_participants", { testid: test_id });
  if (error) console.error("RPC error:", error);
} catch (e) {
  console.error("RPC crash:", e);
}


    return res.json({ attempt });
  } catch (err) {
    console.error("❌ startTest error", err);
    return res.status(500).json({ error: err.message });
  }
};

/* ==========================================================
   GET QUESTIONS
========================================================== */
export const getQuestions = async (req, res) => {
  try {
    const { test_id } = req.params;

    const { data, error } = await supabase
      .from("mock_test_questions")
      .select("id, question, option_a, option_b, option_c, option_d, correct_option")
      .eq("test_id", test_id)
      .order("id");

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data || []);
  } catch (err) {
    console.error("❌ getQuestions error", err);
    return res.status(500).json({ error: err.message });
  }
};

/* ==========================================================
   SAVE ANSWER (Upsert + progress update)
========================================================== */
export const saveAnswer = async (req, res) => {
  try {
    const { attempt_id, question_id, answer } = req.body;

    if (!attempt_id || !question_id || !answer) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    /* 1️⃣ Save / update answer */
    const { error: upsertErr } = await supabase
      .from("mock_answers")
      .upsert({
        attempt_id,
        question_id,
        answer,
      });

    if (upsertErr) {
      return res.status(400).json({ error: upsertErr.message });
    }

    /* 2️⃣ Count completed answers */
    const { count, error: countErr } = await supabase
      .from("mock_answers")
      .select("*", { count: "exact", head: true })
      .eq("attempt_id", attempt_id);

    if (countErr) {
      return res.status(400).json({ error: countErr.message });
    }

    /* 3️⃣ Update progress */
    await supabase
      .from("mock_attempts")
      .update({ completed_questions: count })
      .eq("id", attempt_id);

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ saveAnswer error", err);
    return res.status(500).json({ error: err.message });
  }
};

/* ==========================================================
   FINISH TEST
========================================================== */
export const finishTest = async (req, res) => {
  try {
    const { attempt_id } = req.body;
    const user_id = req.user.id;

    if (!attempt_id) {
      return res.status(400).json({ error: "Missing attempt_id" });
    }

    /* 1️⃣ Get attempt details */
    const { data: attempt, error: attErr } = await supabase
      .from("mock_attempts")
      .select("test_id, started_at, status")
      .eq("id", attempt_id)
      .single();

    if (attErr || !attempt) {
      return res.status(404).json({ error: "Attempt not found" });
    }

    if (attempt.status === "completed") {
      return res.json({ already_finished: true });
    }

    /* 2️⃣ Calculate score */
    const { score, percentScore } = await calculateScore(
      attempt_id,
      attempt.test_id
    );

    /* 3️⃣ Calculate time spent */
    const started = new Date(attempt.started_at);
    const now = new Date();
    const timeSpent = Math.max(
      Math.round((now - started) / 1000 / 60),
      1
    ); // min 1 min

    /* 4️⃣ Update attempt */
    await supabase
      .from("mock_attempts")
      .update({
        status: "completed",
        score: percentScore,
        completed_at: now,
        time_spent: timeSpent,
      })
      .eq("id", attempt_id);

    /* 5️⃣ Update analytics async */
    Promise.all([
      updateLeaderboard(user_id),
      updateUserStats(user_id, percentScore, timeSpent),
      updateRanks(),
    ]).catch(() => {});

    return res.json({
      success: true,
      score: percentScore,
      time_spent: timeSpent,
    });
  } catch (err) {
    console.error("❌ finishTest error", err);
    return res.status(500).json({ error: err.message });
  }
};

/* ==========================================================
   CHECK ATTEMPT STATUS
========================================================== */
export const getAttemptStatus = async (req, res) => {
  try {
    const { attempt_id } = req.params;

    const { data, error } = await supabase
      .from("mock_attempts")
      .select("*")
      .eq("id", attempt_id)
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json(data || {});
  } catch (err) {
    console.error("❌ getAttemptStatus error", err);
    return res.status(500).json({ error: err.message });
  }
};

/* ==========================================================
   SCORE CALCULATION
========================================================== */
async function calculateScore(attempt_id, test_id) {
  const { data: questions } = await supabase
    .from("mock_test_questions")
    .select("id, correct_option")
    .eq("test_id", test_id);

  const { data: answers } = await supabase
    .from("mock_answers")
    .select("question_id, answer")
    .eq("attempt_id", attempt_id);

  let correct = 0;

  questions.forEach((q) => {
    const a = answers.find((x) => x.question_id === q.id);
    if (a && a.answer === q.correct_option) correct++;
  });

  return {
    score: correct,
    percentScore: Math.round((correct / questions.length) * 100),
  };
}

/* ==========================================================
   UPDATE LEADERBOARD
========================================================== */
async function updateLeaderboard(user_id) {
  const { data } = await supabase
    .from("mock_attempts")
    .select("score")
    .eq("user_id", user_id)
    .eq("status", "completed");

  if (!data || data.length === 0) return;

  const scores = data.map((x) => x.score);
  const avg = Math.round(scores.reduce((a, b) => a + b) / scores.length);

  await supabase.from("mock_leaderboard").upsert({
    user_id,
    average_score: avg,
    tests_taken: scores.length,
  });
}

/* ==========================================================
   UPDATE USER STATS
========================================================== */
async function updateUserStats(user_id, newScore, timeSpent) {
  const { data: stats } = await supabase
    .from("user_stats")
    .select("*")
    .eq("user_id", user_id)
    .maybeSingle();

  if (!stats) {
    await supabase.from("user_stats").insert({
      user_id,
      tests_taken: 1,
      average_score: newScore,
      best_rank: null,
      total_study_time: timeSpent,
    });
    return;
  }

  const totalTests = stats.tests_taken + 1;
  const avgScore =
    Math.round(
      (stats.average_score * stats.tests_taken + newScore) / totalTests
    );

  await supabase
    .from("user_stats")
    .update({
      tests_taken: totalTests,
      average_score: avgScore,
      total_study_time: stats.total_study_time + timeSpent,
    })
    .eq("user_id", user_id);
}

/* ==========================================================
   UPDATE RANKS (GLOBAL)
========================================================== */
async function updateRanks() {
  const { data: board } = await supabase
    .from("mock_leaderboard")
    .select("user_id, average_score")
    .order("average_score", { ascending: false });

  if (!board) return;

  for (let i = 0; i < board.length; i++) {
    const rank = i + 1;
    const user_id = board[i].user_id;

    await supabase
      .from("mock_leaderboard")
      .update({ best_rank: rank })
      .eq("user_id", user_id);

    await supabase
      .from("mock_attempts")
      .update({ rank })
      .eq("user_id", user_id)
      .eq("status", "completed");
  }
}
