import express from "express";
import multer from "multer";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  getUserProfile,
  updateUserProfile,
  uploadAvatar,
  changePassword,
  updatePreferences,
  updateNotifications,
  toggleTwoFactor,
  getSessions,
  revokeSession,
} from "../controllers/profileController.js";

const router = express.Router();

// 📸 Multer for in-memory file uploads
const upload = multer({ storage: multer.memoryStorage() });

/* -------------------------------------------------------------------------- */
/* 📌 USER PROFILE                                                             */
/* -------------------------------------------------------------------------- */
router.get("/", verifySupabaseAuth, getUserProfile);
router.put("/", verifySupabaseAuth, updateUserProfile);

/* -------------------------------------------------------------------------- */
/* 🖼️ AVATAR UPLOAD                                                            */
/* -------------------------------------------------------------------------- */
router.post(
  "/avatar",
  verifySupabaseAuth,
  upload.single("avatar"),
  uploadAvatar
);

/* -------------------------------------------------------------------------- */
/* 🔐 SECURITY                                                                 */
/* -------------------------------------------------------------------------- */
router.put("/security/password", verifySupabaseAuth, changePassword);
router.put("/security/2fa", verifySupabaseAuth, toggleTwoFactor);

/* -------------------------------------------------------------------------- */
/* 🎨 PREFERENCES                                                              */
/* -------------------------------------------------------------------------- */
router.put("/preferences", verifySupabaseAuth, updatePreferences);

/* -------------------------------------------------------------------------- */
/* 🔔 NOTIFICATIONS                                                            */
/* -------------------------------------------------------------------------- */
router.put("/notifications", verifySupabaseAuth, updateNotifications);

/* -------------------------------------------------------------------------- */
/* 🖥️ SESSIONS                                                                 */
/* -------------------------------------------------------------------------- */
router.get("/sessions", verifySupabaseAuth, getSessions);
router.delete("/sessions/:id", verifySupabaseAuth, revokeSession);

export default router;
