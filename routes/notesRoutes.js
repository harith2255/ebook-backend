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
router.get("/", getAllNotes);
router.get("/:id/preview-pdf", getNotePreviewPdf);

/* ============================
   PROTECTED ROUTES
============================= */
router.get("/purchased/all", verifySupabaseAuth.required, getPurchasedNotes);
router.get("/downloaded", verifySupabaseAuth.required, getDownloadedNotes);

// 🔐 DRM ONLY FOR DOWNLOAD
router.post(
  "/:id/download",
  verifySupabaseAuth.required,
  drmCheck,
  incrementDownloads
);

// Reading metadata (NO DRM)
router.get("/:id", verifySupabaseAuth.required, getNoteById);

// Highlights (NO DRM)
router.get("/highlights/:id", verifySupabaseAuth.required, getNoteHighlights);
router.post("/highlights", verifySupabaseAuth.required, addNoteHighlight);
router.delete("/highlights/:id", verifySupabaseAuth.required, deleteNoteHighlight);

// Last page (NO DRM)
router.get("/lastpage/:id", verifySupabaseAuth.required, getNoteLastPage);
router.put("/lastpage/:id", verifySupabaseAuth.required, saveNoteLastPage);

export default router;
