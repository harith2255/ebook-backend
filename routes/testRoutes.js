import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  startTest,
  getQuestions,
  saveAnswer,
  finishTest,
  getAttemptStatus,
} from "../controllers/testController.js";

const router = express.Router();

router.post("/start", verifySupabaseAuth.required, startTest);
router.get("/questions/:test_id", verifySupabaseAuth.required, getQuestions);

router.post("/save-answer", verifySupabaseAuth.required, saveAnswer);
router.post("/finish", verifySupabaseAuth.required, finishTest);

router.get("/attempt/:attempt_id", verifySupabaseAuth.required, getAttemptStatus);

export default router;
