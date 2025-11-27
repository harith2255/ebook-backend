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

router.post("/unified", verifySupabaseAuth, unifiedPurchase);

router.get("/check", verifySupabaseAuth, checkPurchase);

router.get("/purchased/books", verifySupabaseAuth, getPurchasedBooks);
router.get("/purchased/book-ids", verifySupabaseAuth, getPurchasedBookIds);
router.get("/purchased/note-ids", verifySupabaseAuth, getPurchasedNoteIds);

router.get("/notes/ids", verifySupabaseAuth, getPurchasedNoteIds);



export default router;
