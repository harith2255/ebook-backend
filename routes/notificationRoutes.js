import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
 getUserNotifications,
  markAllNotificationsRead,
 
  markNotificationRead
} from "../controllers/notificationController.js";

const router = express.Router();

router.get("/", verifySupabaseAuth, getUserNotifications);
router.post("/:id/read", verifySupabaseAuth, markNotificationRead);
router.patch("/read-all", verifySupabaseAuth, markAllNotificationsRead);

export default router;
