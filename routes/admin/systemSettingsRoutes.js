import express from "express";
import {
  getSystemSettings,
  updateSystemSettings,
  getIntegrations,
  updateIntegration,
  createBackup
} from "../../controllers/admin/systemSettingsController.js";

import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/", verifySupabaseAuth, adminOnly, getSystemSettings);
router.put("/", verifySupabaseAuth, adminOnly, updateSystemSettings);

router.get("/integrations", verifySupabaseAuth, adminOnly, getIntegrations);
router.put("/integrations/:id", verifySupabaseAuth, adminOnly, updateIntegration);


router.post("/backup", verifySupabaseAuth, adminOnly, createBackup);

export default router;
