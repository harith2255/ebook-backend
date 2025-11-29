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
router.get("/", verifySupabaseAuth.required, getUserProfile);
router.put("/", verifySupabaseAuth.required, updateUserProfile);

/* -------------------------------------------------------------------------- */
/* 🖼️ AVATAR UPLOAD                                                            */
/* -------------------------------------------------------------------------- */
router.post(
  "/avatar",
  verifySupabaseAuth.required,
  upload.single("avatar"),
  uploadAvatar
);

/* -------------------------------------------------------------------------- */
/* 🔐 SECURITY                                                                 */
/* -------------------------------------------------------------------------- */
router.put("/security/password", verifySupabaseAuth.required, changePassword);
router.put("/security/2fa", verifySupabaseAuth.required, toggleTwoFactor);

/* -------------------------------------------------------------------------- */
/* 🎨 PREFERENCES                                                              */
/* -------------------------------------------------------------------------- */
router.put("/preferences", verifySupabaseAuth.required, updatePreferences);

/* -------------------------------------------------------------------------- */
/* 🔔 NOTIFICATIONS                                                            */
/* -------------------------------------------------------------------------- */
router.put("/notifications", verifySupabaseAuth.required, updateNotifications);

/* -------------------------------------------------------------------------- */
/* 🖥️ SESSIONS                                                                 */
/* -------------------------------------------------------------------------- */
router.get("/sessions", verifySupabaseAuth.required, getSessions);
router.delete("/sessions/:id", verifySupabaseAuth.required, revokeSession);

export default router;
