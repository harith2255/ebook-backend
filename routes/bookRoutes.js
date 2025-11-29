// routes/bookRoutes.js
import express from "express";
import {
  getAllBooks,
  getBookById,
  searchBooksByName,
  logBookRead,
} from "../controllers/bookController.js";

import { drmCheck } from "../middleware/drmCheck.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

/* -------------------------------
   PUBLIC / USER ROUTES
-------------------------------- */

// Get all books (requires user login)
router.get("/", verifySupabaseAuth.required, getAllBooks);

// Search books by name (requires login)
router.get("/search", verifySupabaseAuth.required, searchBooksByName);

/*
  IMPORTANT:
  drmCheck BEFORE reading a book.
  ✔ checks subscription
  ✔ checks device limits
  ✔ logs access
  ✔ returns DRM flags to frontend
*/
router.get("/:id", verifySupabaseAuth.optional, getBookById);

// Log a book reading event
router.post("/read", verifySupabaseAuth.required, drmCheck, logBookRead);

export default router;
