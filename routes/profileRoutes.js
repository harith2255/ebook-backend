import express from "express";
import {
  getUserProfile,
  updateUserProfile,
  changePassword,
  updatePreferences,
  updateNotifications,
  toggleTwoFactor,
  getSessions,
  revokeSession,
  uploadAvatar,
} from "../controllers/profileController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import multer from "multer";

const upload = multer({ storage: multer.memoryStorage() }); // replace with hardened config above

const router = express.Router();

router.get("/", verifySupabaseAuth, getUserProfile);
router.put("/", verifySupabaseAuth, updateUserProfile);
router.put("/preferences", verifySupabaseAuth, updatePreferences);
router.put("/notifications", verifySupabaseAuth, updateNotifications);
router.put("/security/password", verifySupabaseAuth, changePassword);
router.put("/security/2fa", verifySupabaseAuth, toggleTwoFactor);
router.get("/sessions", verifySupabaseAuth, getSessions);
router.delete("/sessions/:id", verifySupabaseAuth, revokeSession);

// important: multer before controller
router.post("/avatar", verifySupabaseAuth, upload.single("avatar"), uploadAvatar);

export default router;
