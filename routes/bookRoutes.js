import express from "express";
import {
  addBook,
  updateBook,
  deleteBook,
  getAllBooks,
  getBookById,
  searchBooksByName,
  purchaseBook,
  getPurchasedBooks,
  logBookRead
} from "../controllers/bookController.js";

import { drmCheck } from "../middleware/drmCheck.js";
import { verifySupabaseAuth, adminOnly } from "../middleware/authMiddleware.js";

const router = express.Router();

/* -------------------------------
   PUBLIC / USER ROUTES
-------------------------------- */

// Get all books
router.get("/", verifySupabaseAuth, getAllBooks);

// Search books
router.get("/search", verifySupabaseAuth, searchBooksByName);

/*  
  IMPORTANT:
  Add drmCheck BEFORE reading a book.
  This automatically:
  ✔ checks subscription
  ✔ checks device limits
  ✔ logs access
  ✔ returns DRM flags to frontend (copy disable, watermark)
*/
router.get("/:id", verifySupabaseAuth, drmCheck, getBookById);

// User opened a book → log reading event (ALSO DRM)
router.post("/read", verifySupabaseAuth, drmCheck, logBookRead);

/* -------------------------------
   PURCHASE ROUTES
-------------------------------- */

router.post("/purchase", verifySupabaseAuth, purchaseBook);

router.get("/purchased/all", verifySupabaseAuth, getPurchasedBooks);

/* -------------------------------
   ADMIN ROUTES
-------------------------------- */

router.post("/", verifySupabaseAuth, adminOnly, addBook);
router.put("/:id", verifySupabaseAuth, adminOnly, updateBook);
router.delete("/:id", verifySupabaseAuth, adminOnly, deleteBook);

export default router;
