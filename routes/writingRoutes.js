import express from "express";
import {
  getServices,
  createWritingOrder,     // ⭐ Final order creation (after payment)
  getActiveOrders,
  getCompletedOrders,
  updateOrder,
  sendFeedback,
  getFeedbackForOrder,
  uploadUserAttachment,
  getSingleWritingOrder,
  verifyWritingPayment,
  getInterviewMaterials,
  getInterviewMaterialById,
  streamInterviewMaterialPdf,
 
} from "../controllers/writingController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// ---------- PUBLIC ----------
router.get("/services", getServices);

// ---------- AUTH REQUIRED ----------
router.use(verifySupabaseAuth.required);

/* -------------------------------
   USER WRITING ORDER ROUTES
-------------------------------- */
router.post("/payments/verify", verifyWritingPayment);  // Step 1: verify payment
router.post("/order", createWritingOrder);              // Step 2: create final order

router.get("/orders/active", getActiveOrders);
router.get("/orders/completed", getCompletedOrders);

/* ===========================
   USER ROUTES
=========================== */
router.get("/", getInterviewMaterials);
router.get("/:id", getInterviewMaterialById);

router.get(
  "/interview-materials/:id/pdf",
 
  streamInterviewMaterialPdf
);

router.put("/orders/:id", updateOrder);

router.post("/feedback", sendFeedback);
router.get("/feedback/:order_id", getFeedbackForOrder);

router.post("/upload", uploadUserAttachment);

router.get("/order/:id", getSingleWritingOrder);

export default router;
