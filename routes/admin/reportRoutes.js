// routes/admin/reportsRoutes.js
import express from "express";
import {
  getAnalytics,
  getReports,
  generateReport,
  downloadReport,
} from "../../controllers/admin/reportController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/analytics", verifySupabaseAuth.required, adminOnly, getAnalytics);

router.get("/", verifySupabaseAuth.required, adminOnly, getReports);

router.post(
  "/generate",
  verifySupabaseAuth.required,
  adminOnly,
  generateReport
);

router.get(
  "/:id/download",
  verifySupabaseAuth.required,
  adminOnly,
  downloadReport
);

export default router;
