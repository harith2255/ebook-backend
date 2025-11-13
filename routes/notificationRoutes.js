import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
 getUserNotifications,
  markNotificationRead
} from "../controllers/notificationController.js";

const router = express.Router();

router.get("/", verifySupabaseAuth, getUserNotifications);
router.post("/:id/read", verifySupabaseAuth, markNotificationRead);

export default router;
