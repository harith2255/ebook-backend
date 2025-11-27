// routes/bookRoutes.js
import express from "express";
import {
  getAllBooks,
  getBookById,
  searchBooksByName,
  logBookRead
} from "../controllers/bookController.js";

import { drmCheck } from "../middleware/drmCheck.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

/* -------------------------------
   PUBLIC / USER ROUTES
-------------------------------- */

// Get all books (with optional filters)
router.get("/", verifySupabaseAuth, getAllBooks);

// Search books by name
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

/* ============================
   PURCHASE ROUTES MOVED
   
   All purchase-related endpoints have been moved to:
   /api/purchase/*
   
   See purchaseRoutes.js for:
   - POST /api/purchase (single book)
   - POST /api/purchase/unified (cart)
   - GET /api/purchase/check
   - GET /api/purchase/books/all (purchased books)
============================= */

export default router;