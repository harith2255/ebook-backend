import express from "express";
import {
  registerDevice,
  checkDRMAccess,
  logAccessEvent,
} from "../controllers/userDrmController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/register-device", verifySupabaseAuth.required, registerDevice);
router.get("/check-access", verifySupabaseAuth.required, checkDRMAccess);
router.post("/log", verifySupabaseAuth.required, logAccessEvent);

export default router;
