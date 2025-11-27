// routes/purchaseRoutes.js
import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  unifiedPurchase,
  purchaseNote,
  checkPurchase,
  getPurchasedBooks,
  getPurchasedBookIds,
  getPurchasedNoteIds
} from "../controllers/purchaseController.js";

const router = express.Router();

/* ======================================
   UNIFIED PURCHASE (Recommended)
   - Works for cart
   - Works for single item
====================================== */
router.post("/unified", verifySupabaseAuth, unifiedPurchase);

/* ======================================
   SINGLE PURCHASE - LEGACY SUPPORT
====================================== */
// Book
router.post("/", verifySupabaseAuth, getPurchasedBooks);
router.post("/book", verifySupabaseAuth, getPurchasedBookIds);

// Note
router.post("/note", verifySupabaseAuth, purchaseNote);
router.post("/notes", verifySupabaseAuth, purchaseNote);

/* ======================================
   CHECK PURCHASE STATUS (Notes + Books)
   Example:
   /api/purchase/check?type=note&noteId=4
====================================== */
router.get("/check", verifySupabaseAuth, checkPurchase);

/* ======================================
   GET PURCHASED BOOKS (Full Data)
====================================== */
router.get("/books/all", verifySupabaseAuth, getPurchasedBooks);

/* ======================================
   GET PURCHASED BOOK IDS
====================================== */
router.get("/books/ids", verifySupabaseAuth, getPurchasedBookIds);

/* ======================================
   GET PURCHASED NOTE IDS  (IMPORTANT)
   Used by notes repository page
====================================== */
router.get("/notes/ids", verifySupabaseAuth, getPurchasedNoteIds);


export default router;
