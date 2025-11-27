// routes/cartRoutes.js
import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  getCart,
  addToCart,
  removeCartItem,
  removePurchasedCartItems
} from "../controllers/cartController.js";

const router = express.Router();

/* ROUTES */
router.get("/", verifySupabaseAuth, getCart);
router.post("/add", verifySupabaseAuth, addToCart);
router.delete("/:id", verifySupabaseAuth, removeCartItem);
// DELETE /api/cart/remove-purchased
router.delete("/remove-purchased", verifySupabaseAuth, removePurchasedCartItems);
export default router;