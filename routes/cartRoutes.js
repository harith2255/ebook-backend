// routes/cartRoutes.js
import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  getCart,
  addToCart,
  removeCartItem,
  removePurchasedCartItems,
} from "../controllers/cartController.js";

const router = express.Router();

/* ROUTES */
router.get("/", verifySupabaseAuth.required, getCart);

router.post("/add", verifySupabaseAuth.required, addToCart);

router.delete("/:id", verifySupabaseAuth.required, removeCartItem);

// DELETE /api/cart/remove-purchased
router.delete(
  "/remove-purchased",
  verifySupabaseAuth.required,
  removePurchasedCartItems
);

export default router;
