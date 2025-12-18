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
  getNotePreviewPdf,
} from "../controllers/notesController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import { drmCheck } from "../middleware/drmCheck.js";

const router = express.Router();

/* ============================
   PUBLIC ROUTES
============================= */

// Public notes listing
router.get("/", getAllNotes);

/* ============================
   PROTECTED ROUTES
============================= */

// Get user's purchased notes
router.get("/purchased/all", verifySupabaseAuth.required, getPurchasedNotes);

// Get user's download history
router.get("/downloaded", verifySupabaseAuth.required, getDownloadedNotes);

// Download a note (increments download count)
router.post(
  "/:id/download",
  verifySupabaseAuth.required,
  drmCheck,
  incrementDownloads
);
// routes/notes.js
router.get("/:id/preview-pdf", getNotePreviewPdf);
// Get note details + DRM
router.get("/:id", verifySupabaseAuth.required, getNoteById);

// Note Highlights
router.get("/highlights/:id", verifySupabaseAuth.required, getNoteHighlights);
router.post("/highlights", verifySupabaseAuth.required, addNoteHighlight);
router.delete(
  "/highlights/:id",
  verifySupabaseAuth.required,
  deleteNoteHighlight
);


// Last page tracking
router.get("/lastpage/:id", verifySupabaseAuth.required, getNoteLastPage);
router.put("/lastpage/:id", verifySupabaseAuth.required, saveNoteLastPage);

export default router;
