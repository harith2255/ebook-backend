// routes/admin/reportsRoutes.js
import express from "express";
import {
  getAnalytics,
  getReports,
  generateReport,
  downloadReport
} from "../../controllers/admin/reportController.js";

import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/analytics", verifySupabaseAuth, adminOnly, getAnalytics);
router.get("/", verifySupabaseAuth, adminOnly, getReports);
router.post("/generate", verifySupabaseAuth, adminOnly, generateReport);
router.get("/:id/download", verifySupabaseAuth, adminOnly, downloadReport);

export default router;
