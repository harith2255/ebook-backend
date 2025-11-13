import express from "express";
import {
  getServices,
  placeOrder,
  getActiveOrders,
  getCompletedOrders,
  updateOrder,
  sendFeedback,
  getFeedbackForOrder,
} from "../controllers/writingController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// Public
router.get("/services", getServices);

// Authenticated user routes
router.use(verifySupabaseAuth);
router.post("/order", placeOrder);
router.get("/orders/active", getActiveOrders);
router.get("/orders/completed", getCompletedOrders);
router.put("/orders/:id", updateOrder);
router.post("/feedback", sendFeedback);
router.get("/feedback/:order_id", getFeedbackForOrder);

export default router;
