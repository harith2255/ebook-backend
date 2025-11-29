import express from "express";
import {
  sendNotification,
  saveDraft,
  getNotifications,
} from "../../controllers/admin/notificationController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/logs", verifySupabaseAuth.required, adminOnly, getNotifications);
router.post("/send", verifySupabaseAuth.required, adminOnly, sendNotification);
router.post("/draft", verifySupabaseAuth.required, adminOnly, saveDraft);

// Duplicate base route, but OK
router.get("/", verifySupabaseAuth.required, adminOnly, getNotifications);

export default router;
