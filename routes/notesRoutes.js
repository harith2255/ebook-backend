import express from "express";
import {
  getAllNotes,
  getNoteById,
  addNote,
  incrementDownloads,
  getFeaturedNotes,
} from "../controllers/notesController.js";

const router = express.Router();

// Public
router.get("/", getAllNotes);
router.get("/featured", getFeaturedNotes);
router.get("/:id", getNoteById);
router.post("/:id/download", incrementDownloads);


export default router;
