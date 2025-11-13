import express from "express";
import {
  getTestQuestions,
  getAttemptDetails,
  saveAnswer,
  finishTest
} from "../controllers/testController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

/* -----------------------------------------
   📌 Attempt details (must be FIRST)
------------------------------------------ */
router.get("/attempt/:attempt_id", verifySupabaseAuth, getAttemptDetails);

/* -----------------------------------------
   📌 Submit / Auto-save answer
------------------------------------------ */
router.post("/save-answer", verifySupabaseAuth, saveAnswer);

/* -----------------------------------------
   📌 Finish / Submit test
------------------------------------------ */
router.post("/finish", verifySupabaseAuth, finishTest);

/* -----------------------------------------
   📌 Questions (must be LAST because of `:test_id`)
------------------------------------------ */
router.get("/:test_id/questions", verifySupabaseAuth, getTestQuestions);

export default router;
