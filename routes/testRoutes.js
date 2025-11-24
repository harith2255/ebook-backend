import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
  startTest,
  getQuestions,
  saveAnswer,
  finishTest,
  getAttemptStatus
} from "../controllers/testController.js";

const router = express.Router();

router.post("/start", verifySupabaseAuth, startTest);
router.post("/save-answer", verifySupabaseAuth, saveAnswer);
router.post("/finish", verifySupabaseAuth, finishTest);
router.get("/attempt/:attempt_id", verifySupabaseAuth, getAttemptStatus);

export default router;
