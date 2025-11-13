// routes/bookRoutes.js
import express from "express";
import {
  addBook,
  updateBook,
  deleteBook,
  getAllBooks,
  getBookById,
  searchBooksByName,
  getPurchasedBooks,
  purchaseBook,
} from "../controllers/bookController.js";
import { verifySupabaseAuth, adminOnly } from "../middleware/authMiddleware.js";

const router = express.Router();




// ✅ Public/User routes
router.get("/", getAllBooks);
router.get("/:id", getBookById);
router.get("/search/name", searchBooksByName);

// ✅ User routes (require login)
router.get("/user/purchased", verifySupabaseAuth, getPurchasedBooks);
router.post("/user/purchase", verifySupabaseAuth, purchaseBook);

export default router;
