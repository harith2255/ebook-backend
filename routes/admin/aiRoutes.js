import express from "express";
import {
  getAISettings,
  updateAISettings,
  processContentAI,
  getAILogs,semanticSearch,
  recommendBooks
} from "../../controllers/admin/aiController.js";

import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

/* ✅ GET & UPDATE AI settings */
router.get("/settings", verifySupabaseAuth, adminOnly, getAISettings);
router.put("/settings", verifySupabaseAuth, adminOnly, updateAISettings);

/* ✅ Process content with AI */
router.post("/process/:type/:id", verifySupabaseAuth, adminOnly, processContentAI);

/* ✅ AI Logs */
router.get("/logs", verifySupabaseAuth, adminOnly, getAILogs);
// ✅ New Features
router.get("/search", verifySupabaseAuth, semanticSearch);
router.get("/recommend", verifySupabaseAuth, recommendBooks);

export default router;
