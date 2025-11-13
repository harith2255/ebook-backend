import express from "express";
import {
  sendNotification,
  saveDraft,
  getNotifications,

} from "../../controllers/admin/notificationController.js";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

router.post("/send", verifySupabaseAuth, adminOnly, sendNotification);
router.post("/draft", verifySupabaseAuth, adminOnly, saveDraft);
router.get("/", verifySupabaseAuth, adminOnly, getNotifications);

export default router;
