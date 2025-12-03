import express from "express";
import {
  getPlans,
  getActiveSubscription,
  upgradeSubscription,
  getSinglePlan,
  cancelSubscription,
} from "../controllers/subscriptionController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();



// Protected
router.get("/active", verifySupabaseAuth.required, getActiveSubscription);
router.post("/upgrade", verifySupabaseAuth.required, upgradeSubscription);
router.post("/cancel", verifySupabaseAuth.required, cancelSubscription);
// Public
router.get("/plans", getPlans);
router.get("/:id", getSinglePlan);

export default router;
