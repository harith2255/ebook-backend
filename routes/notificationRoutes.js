import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
  getUserNotifications,
  markAllNotificationsRead,
  markNotificationRead
} from "../controllers/notificationController.js";

const router = express.Router();

// GET all notifications
router.get("/", verifySupabaseAuth, getUserNotifications);

// MARK ONE as read (IMPORTANT: must match frontend)
router.patch("/read/:id", verifySupabaseAuth, markNotificationRead);

// MARK ALL as read
router.patch("/read-all", verifySupabaseAuth, markAllNotificationsRead);

export default router;
