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

    // 1. Fetch test metadata
    const { data: test, error: testErr } = await supabase
      .from("mock_tests")
      .select("id, start_time, duration_minutes")
      .eq("id", test_id)
      .single();

    if (testErr || !test) {
      return res.status(404).json({ error: "Test not found" });
    }

    // 2. Check schedule
    if (test.start_time && new Date(test.start_time) > new Date()) {
      return res.status(400).json({ error: "This test has not started yet" });
    }

    // 3. Check previous attempt
    const { data: priorAttempt } = await supabase
      .from("mock_attempts")
      .select("id, status")
      .eq("user_id", user_id)
      .eq("test_id", test_id)
      .maybeSingle();

    // 4. If already in-progress -> resume
    if (priorAttempt && priorAttempt.status === "in_progress") {
      return res.json({
        attempt: priorAttempt,
        already_started: true,
      });
    }

    // 5. Create new attempt (ALWAYS INSERT)
    const { data: attempt, error: insertErr } = await supabase
      .from("mock_attempts")
      .insert({
        user_id,
        test_id,
        status: "in_progress",
        completed_questions: 0,
        score: 0,
        time_spent: 0,
        started_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (insertErr) {
      console.error(insertErr);
      return res.status(400).json({ error: insertErr.message });
    }




    return res.json({ attempt });

  } catch (err) {
    console.error("❌ startTest error", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};



/* ==========================================================
   GET QUESTIONS
========================================================== */
/* ==========================================================
   GET QUESTIONS (dynamic options + explanation)
========================================================== */
export const getQuestions = async (req, res) => {
  try {
    const { test_id } = req.params;

    console.log("📌 Incoming Test ID:", test_id);

    const { data, error } = await supabase
      .from("mock_test_questions")
      .select(`
        id,
        question,
        option_a,
        option_b,
        option_c,
        option_d,
        option_e,
        correct_option,
        explanation
      `)
      .eq("test_id", test_id)
      .order("id");

    console.log("📥 Raw DB Data:", data);
    console.log("⚠️ DB Error:", error);

    if (error) {
      console.error("❌ Supabase error in getQuestions:", error);
      return res.status(400).json({ error: error.message });
    }

    if (!data || data.length === 0) {
      console.warn("⚠️ No questions found for test:", test_id);
      return res.json({ mock_test_questions: [] });
    }

    const formatted = data.map((q) => {
      console.log("➡️ Processing Question:", q.id, "Explanation:", q.explanation);

      return {
        id: q.id,
        question: q.question,
        options: [
          q.option_a,
          q.option_b,
          q.option_c,
          q.option_d,
          q.option_e
        ].filter(Boolean),
        correct_option: q.correct_option,
        explanation: q.explanation || ""   // add fallback
      };
    });

    console.log("📤 Final formatted questions:", formatted);

    return res.json({
      mock_test_questions: formatted,
    });

  } catch (err) {
    console.error("🔥 CRITICAL getQuestions ERROR:", err);
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

    // validate question belongs to attempt’s test
    const { data: attempt } = await supabase
      .from("mock_attempts")
      .select("test_id")
      .eq("id", attempt_id)
      .maybeSingle();

    if (!attempt) {
      return res.status(404).json({ error: "Attempt not found" });
    }

    const { data: question } = await supabase
      .from("mock_test_questions")
      .select("test_id")
      .eq("id", question_id)
      .maybeSingle();

    if (!question || question.test_id !== attempt.test_id) {
      return res.status(400).json({ error: "Invalid question for this test" });
    }

    // Save answer
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

    // Count answered
    const { count, error: countErr } = await supabase
      .from("mock_answers")
      .select("*", { count: "exact", head: true })
      .eq("attempt_id", attempt_id);

    if (countErr) {
      return res.status(400).json({ error: countErr.message });
    }

    // update progress
    await supabase
      .from("mock_attempts")
      .update({ completed_questions: count })
      .eq("id", attempt_id);

    return res.json({ success: true });

  } catch (err) {
    console.error("saveAnswer error:", err);
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

    // load attempt
    const { data: attempt } = await supabase
      .from("mock_attempts")
      .select("test_id, started_at, status")
      .eq("id", attempt_id)
      .maybeSingle();

    if (!attempt) {
      return res.status(404).json({ error: "Attempt not found" });
    }

    if (attempt.status === "completed") {
      return res.json({ already_finished: true });
    }

    // Score
    const { score, percentScore } = await calculateScore(
      attempt_id,
      attempt.test_id
    );

    // Time spent
    const started = new Date(attempt.started_at);
    const now = new Date();
    const timeSpent = Math.max(
      Math.round((now - started) / 60000),
      1
    );

    // Update attempt
    await supabase
      .from("mock_attempts")
      .update({
        status: "completed",
        score: percentScore,
        completed_at: now,
        time_spent: timeSpent,
      })
      .eq("id", attempt_id);

      // 2. Recalculate study time AFTER completion
const totalStudyTime = await recalculateStudyTime(user_id);

await supabase
  .from("user_stats")
  .update({
    total_study_time: totalStudyTime
  })
  .eq("user_id", user_id);

    // async analytics
// async analytics (ORDER MATTERS)
await updateTestRanks(attempt.test_id);
await updateTestPercentiles(attempt.test_id);
await updateUserBestRank(user_id);

updateLeaderboard(user_id).catch(() => {});
updateUserStats(user_id, percentScore, timeSpent).catch(() => {});

    

    return res.json({
      success: true,
      score: percentScore,
      time_spent: timeSpent,
    });

  } catch (err) {
    console.error("finishTest error:", err);
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

  if (!data?.length) return;

  const avg = Math.round(
    data.reduce((a, b) => a + b.score, 0) / data.length
  );

  await supabase.from("mock_leaderboard").upsert({
    user_id,
    average_score: avg,
    tests_taken: data.length,
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
  })
  .eq("user_id", user_id);

}
async function recalculateStudyTime(user_id) {
  const { data: attempts } = await supabase
    .from("mock_attempts")
    .select("test_id, time_spent, score")
    .eq("user_id", user_id)
    .eq("status", "completed")
    .order("score", { ascending: false });

  if (!attempts) return 0;

  const seen = new Set();
  let total = 0;

  for (const a of attempts) {
    if (!seen.has(a.test_id)) {
      seen.add(a.test_id);
      total += a.time_spent || 0;
    }
  }

  return total;
}

async function getBestAttemptsForTest(test_id) {
  const { data } = await supabase
    .from("mock_attempts")
    .select("id, user_id, score, time_spent, rank")
    .eq("test_id", test_id)
    .eq("status", "completed")
    .order("score", { ascending: false })
    .order("time_spent", { ascending: true });

  if (!data) return [];

  const seen = new Set();
  const best = [];

  for (const a of data) {
    if (!seen.has(a.user_id)) {
      seen.add(a.user_id);
      best.push(a);
    }
  }

  return best;
}

async function updateTestRanks(test_id) {
  const attempts = await getBestAttemptsForTest(test_id);
  if (!attempts.length) return;

  let rank = 1;

  for (let i = 0; i < attempts.length; i++) {
    if (
      i > 0 &&
      attempts[i].score < attempts[i - 1].score
    ) {
      rank = i + 1;
    }

    await supabase
      .from("mock_attempts")
      .update({ rank })
      .eq("id", attempts[i].id);
  }
}
async function updateTestPercentiles(test_id) {
  const attempts = await getBestAttemptsForTest(test_id);
  if (!attempts.length) return;

  const total = attempts.length;

  for (const a of attempts) {
    const below = total - a.rank;
    const percentile = Math.round((below / total) * 100);

    await supabase
      .from("mock_attempts")
      .update({ percentile })
      .eq("id", a.id);
  }
}
async function updateUserBestRank(user_id) {
  const { data } = await supabase
    .from("mock_attempts")
    .select("rank")
    .eq("user_id", user_id)
    .eq("status", "completed")
    .not("rank", "is", null);

  if (!data || !data.length) return;

  const bestRank = Math.min(...data.map(r => r.rank));

  await supabase
    .from("user_stats")
    .update({ best_rank: bestRank })
    .eq("user_id", user_id);
}
