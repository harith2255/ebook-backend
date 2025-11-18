import express from "express";
import { getTransactions, getPaymentMethods, addPaymentMethod } from "../controllers/paymentController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

router.get("/transactions", verifySupabaseAuth, getTransactions);
router.get("/methods", verifySupabaseAuth, getPaymentMethods);
router.post("/methods", verifySupabaseAuth, addPaymentMethod);

export default router;
