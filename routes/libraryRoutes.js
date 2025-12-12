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
  updateReadingProgress,
  startReading,
  markBookCompleted,
  getHighlightsForBook,
  saveHighlight,
  deleteHighlight,
  getLastPage,
  saveLastPage,
  saveStudySession,
  updateCollection,
  getCollectionBookIds,
  resetReading,
  removeBookFromAllCollections,
} from "../controllers/libraryController.js";

const router = express.Router();

// Require login for ALL routes in this file
router.use(verifySupabaseAuth.required);

// ----- 📚 Library Routes -----
router.get("/", getUserLibrary);
router.post("/add/:bookId", addBookToLibrary);
router.delete("/remove/:bookId", removeBookFromLibrary);
router.get("/recent", getRecentBooks);
router.get("/reading", getCurrentlyReading);
router.get("/completed", getCompletedBooks);
router.get("/search", searchLibrary);
router.put("/progress/:bookId", updateReadingProgress);
router.post("/read/start", startReading);
router.put("/complete/:bookId", markBookCompleted);
router.post("/study-session", saveStudySession);
router.put(
  "/reset/:bookId",
  resetReading
);

// ----- 📄 Last Page Routes -----
router.get("/lastpage/:bookId", getLastPage);
router.put("/lastpage/:bookId", saveLastPage);

// ----- 🖍 Highlight Routes -----
router.post("/highlights", saveHighlight);
router.get("/highlights/:bookId", getHighlightsForBook);
router.delete("/highlights/:id", deleteHighlight);

// ----- 📂 Collection Routes -----
router.post("/collections", createCollection);
router.get("/collections", getAllCollections);
router.get("/collections/book-ids", getCollectionBookIds);
router.get("/collections/:id/books", getCollectionBooks);
router.post("/collections/:id/add", addBookToCollection);
router.delete("/collections/remove-book/:bookId", removeBookFromAllCollections);


router.delete("/collections/:id/remove/:bookId", removeBookFromCollection);
router.delete("/collections/:id", deleteCollection);
router.put("/collections/:id", updateCollection);

export default router;
