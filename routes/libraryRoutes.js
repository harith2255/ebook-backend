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
  saveStudySession
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
router.put("/progress/:bookId", updateReadingProgress);
router.post("/read/start", startReading);
router.put("/complete/:bookId", markBookCompleted);  
router.post("/study-session", saveStudySession);


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
router.get("/collections/:id/", getCollectionBooks);
router.post("/collections/:id/add/:bookId", addBookToCollection);
router.delete("/collections/:id/remove/:bookId", removeBookFromCollection);
router.delete("/collections/:id", deleteCollection);

export default router;
