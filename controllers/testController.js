// controllers/testController.js
import supabase from "../utils/supabaseClient.js";
import { updateUserStats } from "./mocktestController.js";

/* ----------------------------------------------------
   📌 1. Get ALL QUESTIONS for a test
-----------------------------------------------------*/
export const getTestQuestions = async (req, res) => {
  const { test_id } = req.params;

  const { data, error } = await supabase
    .from("mock_test_questions")
    .select("id, question, option_a, option_b, option_c, option_d, correct_option")
    .eq("test_id", test_id);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ----------------------------------------------------
   📌 2. Get attempt details (test page load)
-----------------------------------------------------*/
export const getAttemptDetails = async (req, res) => {
  const { attempt_id } = req.params;

  const { data, error } = await supabase
    .from("mock_attempts")
    .select(`
      id, test_id, user_id, status, started_at, completed_at,
      mock_tests(id, title, duration_minutes, total_questions)
    `)
    .eq("id", attempt_id)
    .maybeSingle();

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ----------------------------------------------------
   📌 3. Save answer (auto-save)
-----------------------------------------------------*/
export const saveAnswer = async (req, res) => {
  const { attempt_id, question_id, answer } = req.body;

  const { error } = await supabase
    .from("mock_answers")
    .upsert(
      [{ attempt_id, question_id, answer }],
      { onConflict: "attempt_id,question_id" }
    );

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Answer saved" });
};

/* ----------------------------------------------------
   📌 4. Finish Test (score + stats)
-----------------------------------------------------*/
export const finishTest = async (req, res) => {
  const { attempt_id } = req.body;

  // fetch attempt
  const { data: attempt, error: aErr } = await supabase
    .from("mock_attempts")
    .select("user_id, started_at, test_id")
    .eq("id", attempt_id)
    .maybeSingle();

  if (aErr || !attempt) return res.status(400).json({ error: "Attempt not found" });

  const userId = attempt.user_id;

  // fetch answers + correct values
  const { data: answers, error: ansErr } = await supabase
    .from("mock_answers")
    .select(`
      answer,
      mock_test_questions(correct_option)
    `)
    .eq("attempt_id", attempt_id);

  if (ansErr) return res.status(400).json({ error: ansErr.message });

  // calculate score
  let score = 0;
  answers.forEach((a) => {
    if (a.answer === a.mock_test_questions.correct_option) score++;
  });

  const completedAt = new Date();
  const startedAt = new Date(attempt.started_at);
  const timeSpent = Math.floor((completedAt - startedAt) / 60000);

  // update attempt
  const { error: updateErr } = await supabase
    .from("mock_attempts")
    .update({
      status: "completed",
      completed_at: completedAt,
      score,
      time_spent: timeSpent,
    })
    .eq("id", attempt_id);

  if (updateErr) return res.status(400).json({ error: updateErr.message });

  // 🔥 UPDATE USER STATS AFTER FINISH
  await updateUserStats(userId);

  res.json({
    message: "Test finished",
    score,
    timeSpent,
  });
};
