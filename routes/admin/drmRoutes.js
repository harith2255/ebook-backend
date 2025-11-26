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

// ----------------------------------------------------------
//  SETTINGS
// ----------------------------------------------------------
router.get("/settings", verifySupabaseAuth, adminOnly, getDRMSettings);
router.put("/settings", verifySupabaseAuth, adminOnly, updateDRMSettings);

// ----------------------------------------------------------
//  ACCESS LOGS
// ----------------------------------------------------------
router.get("/access-logs", verifySupabaseAuth, adminOnly, getAccessLogs);
// NOTE: Your frontend uses GET /api/drm/access-logs
// So we keep the route as /access-logs


// ----------------------------------------------------------
//  QUICK ACTIONS
// ----------------------------------------------------------
router.post("/watermark", verifySupabaseAuth, adminOnly, addWatermark);

router.get("/licenses", verifySupabaseAuth, adminOnly, getActiveLicenses);
// matches frontend: axios.get("/api/drm/licenses")

router.post("/revoke", verifySupabaseAuth, adminOnly, revokeAccess);


// ----------------------------------------------------------
//  REPORT DOWNLOAD
// ----------------------------------------------------------
router.get("/report", verifySupabaseAuth, adminOnly, downloadAccessReport);

export default router;
