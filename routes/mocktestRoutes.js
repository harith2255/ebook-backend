import express from "express";
import {  verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
  getAvailableTests,
  getOngoingTests,
  getCompletedTests,
  getStats,
  getLeaderboard,
  getTestDetails
} from "../controllers/mocktestController.js";

import {
  startTest,
  saveAnswer,
  finishTest
} from "../controllers/testController.js";  // <-- YOUR START TEST IS HERE

const router = express.Router();

// ------------------ MOCK TESTS ------------------ //
router.get("/test/:id", verifySupabaseAuth, getTestDetails);

router.get("/", verifySupabaseAuth, getAvailableTests);
router.get("/ongoing", verifySupabaseAuth, getOngoingTests);
router.get("/completed", verifySupabaseAuth, getCompletedTests);
router.get("/stats", verifySupabaseAuth, getStats);
router.get("/leaderboard", verifySupabaseAuth, getLeaderboard);

// ------------------ START TEST ------------------ //
router.post("/start", verifySupabaseAuth, startTest);   // <-- ADD THIS

// ------------------ TEST ACTIONS ------------------ //
router.post("/save-answer", verifySupabaseAuth, saveAnswer);
router.post("/finish", verifySupabaseAuth, finishTest);

export default router;
