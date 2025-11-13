import express from "express";
import {
  getAllMockTests,
  startMockTest,
  getOngoingTests,
  getCompletedTests,
  getUserStats,
  getLeaderboard
} from "../controllers/mocktestController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

/* ------------------------------------------
   📘 MOCK TEST LIST + USER PROGRESS ROUTES
-------------------------------------------*/

// Get all available mock tests
router.get("/", verifySupabaseAuth, getAllMockTests);

// Get user's ongoing tests
router.get("/ongoing", verifySupabaseAuth, getOngoingTests);

// Get user's completed tests
router.get("/completed", verifySupabaseAuth, getCompletedTests);

// Get user's stats
router.get("/stats", verifySupabaseAuth, getUserStats);

// Leaderboard
router.get("/leaderboard", verifySupabaseAuth, getLeaderboard);

/* ------------------------------------------
   🚀 START MOCK TEST
-------------------------------------------*/
router.post("/start", verifySupabaseAuth, startMockTest);

export default router;
