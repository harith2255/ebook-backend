import express from "express";
import {
  getAISettings,
  updateAISettings,
  processContentAI,
  getAILogs,
  semanticSearch,
  recommendBooks,
} from "../../controllers/admin/aiController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

/* ✅ GET & UPDATE AI settings */
router.get("/settings", verifySupabaseAuth.required, adminOnly, getAISettings);
router.put(
  "/settings",
  verifySupabaseAuth.required,
  adminOnly,
  updateAISettings
);

/* ✅ Process content with AI */
router.post(
  "/process/:type/:id",
  verifySupabaseAuth.required,
  adminOnly,
  processContentAI
);

/* ✅ AI Logs */
router.get("/logs", verifySupabaseAuth.required, adminOnly, getAILogs);

/* ✅ New Features (User-level AI functions) */
router.get("/search", verifySupabaseAuth.required, semanticSearch);
router.get("/recommend", verifySupabaseAuth.required, recommendBooks);

export default router;
