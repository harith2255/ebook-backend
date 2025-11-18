import express from "express";
import {
  getAllNotes,
  getFeaturedNotes,
  getNoteById,
  incrementDownloads,
  checkNotePurchase,
  purchaseNote,
  getDownloadedNotes
} from "../controllers/notesController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();


// Public routes
router.get("/", getAllNotes);
router.get("/featured", getFeaturedNotes);

// Protected routes
router.get("/purchase/check", verifySupabaseAuth, checkNotePurchase);
router.post("/purchase", verifySupabaseAuth, purchaseNote);
router.post("/:id/download", verifySupabaseAuth, incrementDownloads);
router.get("/downloaded", verifySupabaseAuth, getDownloadedNotes);


// ❗ DYNAMIC ROUTE MUST BE LAST
router.get("/:id", getNoteById);

export default router;

