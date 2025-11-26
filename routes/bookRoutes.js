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

import { verifySupabaseAuth, adminOnly } from "../middleware/authMiddleware.js";

const router = express.Router();

/* -------------------------------
   PUBLIC / USER ROUTES
-------------------------------- */

// Get all books
// GET /api/books
router.get("/", verifySupabaseAuth, getAllBooks);
router.post("/read", verifySupabaseAuth, logBookRead);

// Search books
// GET /api/books/search?name=
router.get("/search", verifySupabaseAuth, searchBooksByName);

// Get single book
// GET /api/books/:id
router.get("/:id", verifySupabaseAuth, getBookById);

/* -------------------------------
   PURCHASE ROUTES
-------------------------------- */

// Purchase a book
// POST /api/books/purchase
router.post("/purchase", verifySupabaseAuth, purchaseBook);

// Get all purchased books for logged-in user
// GET /api/books/purchased/all
router.get("/purchased/all", verifySupabaseAuth, getPurchasedBooks);

/* -------------------------------
   ADMIN ROUTES
-------------------------------- */

router.post("/", verifySupabaseAuth, adminOnly, addBook);
router.put("/:id", verifySupabaseAuth, adminOnly, updateBook);
router.delete("/:id", verifySupabaseAuth, adminOnly, deleteBook);

export default router;
