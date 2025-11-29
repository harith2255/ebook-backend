import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
  getUserNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "../controllers/notificationController.js";

const router = express.Router();

// GET all notifications
router.get("/", verifySupabaseAuth.required, getUserNotifications);

// MARK ONE as read
router.patch("/read/:id", verifySupabaseAuth.required, markNotificationRead);

// MARK ALL as read
router.patch(
  "/read-all",
  verifySupabaseAuth.required,
  markAllNotificationsRead
);

export default router;
