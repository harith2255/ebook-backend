// src/routes/examRoutes.js
import express from "express";
import multer from "multer";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  listExams,
  getExam,
  attendExam,
  getUserSubmissions,
  getFoldersForUser,
} from "../controllers/examController.js";

const upload = multer();
const router = express.Router();

/* ---------------- USER ROUTES ---------------- */

// User: View folders, notes, exams
router.get("/folders", verifySupabaseAuth.optional, getFoldersForUser);

// User: View user's own submissions
router.get("/submissions/me", verifySupabaseAuth.required, getUserSubmissions);

// User: Attend an exam
router.post(
  "/:id/attend",
  verifySupabaseAuth.required,
  upload.single("answer_file"),
  attendExam
);

/* ---------------- EXAM PUBLIC ROUTES ---------------- */

// List all exams (public)
router.get("/", verifySupabaseAuth.optional, listExams);

// Get exam details (public)
router.get("/:id", verifySupabaseAuth.optional, getExam);

/* ---------------- ADMIN ROUTES ---------------- */
export default router;
