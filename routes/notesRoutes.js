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
import { drmCheck } from "../middleware/drmCheck.js";

const router = express.Router();

/* -------------------------------
   PUBLIC ROUTES
-------------------------------- */
router.get("/", getAllNotes);
router.get("/featured", getFeaturedNotes);

/* -------------------------------
   PROTECTED ROUTES
-------------------------------- */

// Check if user already purchased notes
router.get("/purchase/check", verifySupabaseAuth, checkNotePurchase);

// Purchase note
router.post("/purchase", verifySupabaseAuth, purchaseNote);

// Download (APPLY DRM HERE)
router.post("/:id/download", verifySupabaseAuth, drmCheck, incrementDownloads);

// Get downloaded notes
router.get("/downloaded", verifySupabaseAuth, getDownloadedNotes);

/* ------------------------------------
   IMPORTANT: APPLY DRM BEFORE READING 
-------------------------------------- */

// Read/open a single note (APPLY DRM HERE)
router.get("/:id", verifySupabaseAuth,  getNoteById);




export default router;
