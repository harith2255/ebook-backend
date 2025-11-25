// routes/cartRoutes.js
import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  getCart,
  addToCart,
  removeCartItem,
} from "../controllers/cartController.js";

export const cartRouter = express.Router();

/* ROUTES */
cartRouter.get("/", verifySupabaseAuth, getCart);
cartRouter.post("/add", verifySupabaseAuth, addToCart);
cartRouter.delete("/:id", verifySupabaseAuth, removeCartItem);
