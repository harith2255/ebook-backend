import express from "express";
import {
  getDRMSettings,
  updateDRMSettings,
  addWatermark,
  getActiveLicenses,
  revokeAccess,
  downloadAccessReport,
  getAccessLogs,
  logAccessEvent,

} from "../../controllers/admin/drmController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

// ----------------------------------------------------------
//  SETTINGS
// ----------------------------------------------------------
router.get("/settings", verifySupabaseAuth.required, adminOnly, getDRMSettings);
router.put(
  "/settings",
  verifySupabaseAuth.required,
  adminOnly,
  updateDRMSettings
);
router.post(
  "/log",
  verifySupabaseAuth.required,
  adminOnly,
  logAccessEvent
);

/* ------------------------------
   ACCESS LOGS (ADMIN ONLY)
--------------------------------*/
router.get("/access-logs", verifySupabaseAuth.required, adminOnly, getAccessLogs);
// ----------------------------------------------------------
//  QUICK ACTIONS
// ----------------------------------------------------------
router.post("/watermark", verifySupabaseAuth.required, adminOnly, addWatermark);

router.get(
  "/licenses",
  verifySupabaseAuth.required,
  adminOnly,
  getActiveLicenses
);

router.post("/revoke", verifySupabaseAuth.required, adminOnly, revokeAccess);

// ----------------------------------------------------------
//  REPORT DOWNLOAD
// ----------------------------------------------------------
router.get(
  "/report",
  verifySupabaseAuth.required,
  adminOnly,
  downloadAccessReport
);

export default router;
