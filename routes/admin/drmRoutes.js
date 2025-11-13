import express from "express";
import {
  getDRMSettings,
  updateDRMSettings,
  getAccessLogs,
  addWatermark,
  getActiveLicenses,
  revokeAccess,
  downloadAccessReport
} from "../../controllers/admin/drmController.js";

import {
  verifySupabaseAuth,
  adminOnly
} from "../../middleware/authMiddleware.js";

const router = express.Router();

// ✅ DRM Settings
router.get("/settings", verifySupabaseAuth, adminOnly, getDRMSettings);
router.put("/settings", verifySupabaseAuth, adminOnly, updateDRMSettings);

// ✅ Access Logs
router.get("/logs", verifySupabaseAuth, adminOnly, getAccessLogs);

// ✅ Quick Actions
router.post("/watermark", verifySupabaseAuth, adminOnly, addWatermark);
router.get("/licenses", verifySupabaseAuth, adminOnly, getActiveLicenses);
router.post("/revoke", verifySupabaseAuth, adminOnly, revokeAccess);

// ✅ Download Report
router.get("/report", verifySupabaseAuth, adminOnly, downloadAccessReport);

export default router;
