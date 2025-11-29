import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  getAvailableTests,
  getOngoingTests,
  getCompletedTests,
  getStats,
  getLeaderboard,
  getTestDetails,
} from "../controllers/mocktestController.js";

import {
  startTest,
  saveAnswer,
  finishTest,
} from "../controllers/testController.js";

const router = express.Router();

// ------------------ MOCK TESTS ------------------ //
router.get("/test/:id", verifySupabaseAuth.required, getTestDetails);

router.get("/", verifySupabaseAuth.required, getAvailableTests);
router.get("/ongoing", verifySupabaseAuth.required, getOngoingTests);
router.get("/completed", verifySupabaseAuth.required, getCompletedTests);
router.get("/stats", verifySupabaseAuth.required, getStats);
router.get("/leaderboard", verifySupabaseAuth.required, getLeaderboard);

// ------------------ START TEST ------------------ //
router.post("/start", verifySupabaseAuth.required, startTest);

// ------------------ TEST ACTIONS ------------------ //
router.post("/save-answer", verifySupabaseAuth.required, saveAnswer);
router.post("/finish", verifySupabaseAuth.required, finishTest);

export default router;
