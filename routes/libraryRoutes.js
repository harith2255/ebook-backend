import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import {
  getUserLibrary,
  addBookToLibrary,
  removeBookFromLibrary,
  getRecentBooks,
  getCurrentlyReading,
  getCompletedBooks,
  searchLibrary,
  createCollection,
  getAllCollections,
  getCollectionBooks,
  addBookToCollection,
  removeBookFromCollection,
  deleteCollection,
} from "../controllers/libraryController.js";

const router = express.Router();

router.use(verifySupabaseAuth);

// ----- 📚 Library Routes -----
router.get("/", getUserLibrary);
router.post("/add/:bookId", addBookToLibrary);
router.delete("/remove/:bookId", removeBookFromLibrary);
router.get("/recent", getRecentBooks);
router.get("/reading", getCurrentlyReading);
router.get("/completed", getCompletedBooks);
router.get("/search", searchLibrary);

// ----- 📂 Collection Routes -----
router.post("/collections", createCollection);
router.get("/collections", getAllCollections);
router.get("/collections/:id", getCollectionBooks);
router.post("/collections/:id/add/:bookId", addBookToCollection);
router.delete("/collections/:id/remove/:bookId", removeBookFromCollection);
router.delete("/collections/:id", deleteCollection);

export default router;
