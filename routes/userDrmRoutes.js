import express from "express";
import {

  checkDRMAccess,
  registerDevice,
  logAccessEvent,
} from "../controllers/userDrmController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();


router.get("/check-access", verifySupabaseAuth.required, checkDRMAccess);
router.post("/register-device", verifySupabaseAuth.required, registerDevice);
router.post("/log", verifySupabaseAuth.required, logAccessEvent);

export default router;
