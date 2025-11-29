import express from "express";
import {
  unifiedPurchase,
  checkPurchase,
  getPurchasedBooks,
  getPurchasedBookIds,
  getPurchasedNoteIds,
} from "../controllers/purchaseController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/unified", verifySupabaseAuth.required, unifiedPurchase);

router.get("/check", verifySupabaseAuth.required, checkPurchase);

router.get("/purchased/books", verifySupabaseAuth.required, getPurchasedBooks);

router.get(
  "/purchased/book-ids",
  verifySupabaseAuth.required,
  getPurchasedBookIds
);

router.get(
  "/purchased/note-ids",
  verifySupabaseAuth.required,
  getPurchasedNoteIds
);

// Duplicate route — keeping it for compatibility
router.get("/notes/ids", verifySupabaseAuth.required, getPurchasedNoteIds);

export default router;
