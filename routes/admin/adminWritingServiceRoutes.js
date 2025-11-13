import express from "express";
import {
  getAllOrders,
  getPendingOrders,
  acceptOrder,
  completeOrder,
  rejectOrder,
} from "../../controllers/admin/adminWritingServiceController.js";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/orders", adminOnly,verifySupabaseAuth, getAllOrders);
router.get("/orders/pending", adminOnly,verifySupabaseAuth, getPendingOrders);
router.put("/orders/:id/accept", adminOnly,verifySupabaseAuth, acceptOrder);
router.put("/orders/:id/complete", adminOnly,verifySupabaseAuth ,completeOrder);
router.put("/orders/:id/reject", adminOnly,verifySupabaseAuth, rejectOrder);

export default router;
