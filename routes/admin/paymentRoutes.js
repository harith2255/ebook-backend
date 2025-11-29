import express from "express";
import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";
import {
  getPaymentStats,
  getTransactions,
} from "../../controllers/admin/paymentController.js";

const router = express.Router();

router.get("/stats", verifySupabaseAuth.required, adminOnly, getPaymentStats);
router.get(
  "/transactions",
  verifySupabaseAuth.required,
  adminOnly,
  getTransactions
);

export default router;
