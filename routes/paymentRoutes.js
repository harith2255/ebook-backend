import express from "express";
import {
  getTransactions,
  getPaymentMethods,
  addPaymentMethod,
  setDefaultPaymentMethod,
  deletePaymentMethodById,
} from "../controllers/paymentController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// Protected routes
router.get("/transactions", verifySupabaseAuth.required, getTransactions);

router.get("/methods", verifySupabaseAuth.required, getPaymentMethods);

router.post("/methods", verifySupabaseAuth.required, addPaymentMethod);

router.post(
  "/methods/:id/default",
  verifySupabaseAuth.required,
  setDefaultPaymentMethod
);

router.delete(
  "/methods/:id",
  verifySupabaseAuth.required,
  deletePaymentMethodById
);

export default router;
