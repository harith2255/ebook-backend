import express from "express";
import {

  checkDRMAccess,
  logAccessEvent,
} from "../controllers/userDrmController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();


router.get("/check-access", verifySupabaseAuth.required, checkDRMAccess);
router.post("/log", verifySupabaseAuth.required, logAccessEvent);

export default router;
