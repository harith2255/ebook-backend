import express from "express";
import {
  getServices,
  placeOrder,
  getActiveOrders,
  getCompletedOrders,
  updateOrder,
  sendFeedback,
  getFeedbackForOrder,
  uploadUserAttachment,
  getSingleWritingOrder,
  checkoutWritingOrder,
} from "../controllers/writingController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// ---------- PUBLIC ----------
router.get("/services", getServices);

// ---------- AUTH REQUIRED ----------
router.use(verifySupabaseAuth.required);

// User routes
router.post("/order", placeOrder);
router.get("/orders/active", getActiveOrders);
router.get("/orders/completed", getCompletedOrders);
router.put("/orders/:id", updateOrder);
router.post("/feedback", sendFeedback);
router.get("/feedback/:order_id", getFeedbackForOrder);
router.post("/upload", uploadUserAttachment);

// These already under router.use(required), but keeping required for clarity
router.get("/order/:id", verifySupabaseAuth.required, getSingleWritingOrder);
router.post("/checkout", verifySupabaseAuth.required, checkoutWritingOrder);

export default router;
