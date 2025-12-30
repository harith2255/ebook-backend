import express from "express";
import {
  getServices,
  createWritingOrder,
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

/* ---------- PUBLIC ---------- */
router.get("/services", getServices);

/* ---------- AUTH REQUIRED ---------- */
router.use(verifySupabaseAuth.required);

/* --------------------------------
   ⚠️ INTERVIEW MATERIAL ROUTES
   → MUST come BEFORE dynamic ":id"
---------------------------------- */

// list materials
router.get("/interview-materials", getInterviewMaterials);

// stream pdf of material
router.get("/interview-materials/:id/pdf", streamInterviewMaterialPdf);

// get single material info
router.get("/interview-materials/:id", getInterviewMaterialById);

/* --------------------------------
   WRITING ORDER ROUTES
---------------------------------- */
router.post("/payments/verify", verifyWritingPayment);
router.post("/order", createWritingOrder);

router.get("/orders/active", getActiveOrders);
router.get("/orders/completed", getCompletedOrders);

router.put("/orders/:id", updateOrder);
router.post("/feedback", sendFeedback);
router.get("/feedback/:order_id", getFeedbackForOrder);

router.post("/upload", uploadUserAttachment);
router.get("/order/:id", getSingleWritingOrder);

/* --------------------------------
   ⚠️ OPTIONAL CATCH ROUTE FOR OTHER IDs
   last to avoid conflicts
---------------------------------- */
// router.get("/:id", getInterviewMaterialById); // ← enable ONLY if needed later

export default router;
