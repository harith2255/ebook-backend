// routes/bookRoutes.js
import express from "express";
import {
  getAllBooks,
  getBookById,
  searchBooksByName,
  logBookRead,
  rateEbook
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

router.post(
  "/:id/rate",
  verifySupabaseAuth.required,
  rateEbook
);
router.get("/:id", verifySupabaseAuth.required, getBookById);

// Log a book reading event
router.post("/read", verifySupabaseAuth.required, logBookRead);

export default router;
