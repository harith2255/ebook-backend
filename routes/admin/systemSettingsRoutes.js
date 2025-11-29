import express from "express";
import {
  getSystemSettings,
  updateSystemSettings,
  getIntegrations,
  updateIntegration,
  createBackup,
} from "../../controllers/admin/systemSettingsController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/", verifySupabaseAuth.required, adminOnly, getSystemSettings);
router.put("/", verifySupabaseAuth.required, adminOnly, updateSystemSettings);

router.get(
  "/integrations",
  verifySupabaseAuth.required,
  adminOnly,
  getIntegrations
);
router.put(
  "/integrations/:id",
  verifySupabaseAuth.required,
  adminOnly,
  updateIntegration
);

router.post("/backup", verifySupabaseAuth.required, adminOnly, createBackup);

export default router;
