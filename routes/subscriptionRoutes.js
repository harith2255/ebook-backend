import express from "express";
import { getPlans, getActiveSubscription, upgradeSubscription } from "../controllers/subscriptionController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

router.get("/plans", getPlans);
router.get("/active", verifySupabaseAuth, getActiveSubscription);
router.post("/upgrade", verifySupabaseAuth, upgradeSubscription);

export default router;
