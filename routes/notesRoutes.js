import express from "express";
import {
  getAllNotes,
  getNoteById,
  incrementDownloads,
  getDownloadedNotes,
  getPurchasedNotes,
  getNoteHighlights,
  addNoteHighlight,
  deleteNoteHighlight,
  getNoteLastPage,
  saveNoteLastPage,
} from "../controllers/notesController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import { drmCheck } from "../middleware/drmCheck.js";

const router = express.Router();

/* ============================
   PUBLIC ROUTES
============================= */
router.get("/", getAllNotes);

/* ============================
   PROTECTED ROUTES
============================= */

// Get user's purchased notes list
router.get("/purchased/all", verifySupabaseAuth, getPurchasedNotes);

// Get user's download history
router.get("/downloaded", verifySupabaseAuth, getDownloadedNotes);

// Download a note (increments download count)
router.post("/:id/download", verifySupabaseAuth, drmCheck, incrementDownloads);

// Get note details (with DRM info)
router.get("/:id", verifySupabaseAuth, drmCheck, getNoteById);

/* ============================
   NOTE: Purchase endpoints moved to purchaseRoutes.js
   Use /api/purchase/notes or /api/purchase/unified
============================= */

router.get("/highlights/:id", verifySupabaseAuth, getNoteHighlights);
router.post("/highlights", verifySupabaseAuth, addNoteHighlight);
router.delete("/highlights/:id", verifySupabaseAuth, deleteNoteHighlight);

router.get("/lastpage/:id", verifySupabaseAuth, getNoteLastPage);
router.put("/lastpage/:id", verifySupabaseAuth, saveNoteLastPage);


export default router;