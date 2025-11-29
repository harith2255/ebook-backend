// src/routes/examRoutes.js
import express from "express";
import multer from "multer";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

import {
  listExams,
  getExam,
  createExam,
  uploadExamFile,
  attendExam,
  getSubmissions,
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
  "/exams/:id/attend",
  verifySupabaseAuth.required,
  upload.single("answer_file"),
  attendExam
);

/* ---------------- EXAM PUBLIC ROUTES ---------------- */

// List all exams (public)
router.get("/exams", verifySupabaseAuth.optional, listExams);

// Get exam details (public)
router.get("/exams/:id", verifySupabaseAuth.optional, getExam);

/* ---------------- ADMIN ROUTES ---------------- */

// Create new exam (admin)
router.post("/exams", verifySupabaseAuth.required, createExam);

// Upload exam PDF (admin)
router.post(
  "/exams/:id/upload-file",
  verifySupabaseAuth.required,
  upload.single("file"),
  uploadExamFile
);

// Admin: view all submissions for an exam
router.get(
  "/exams/:id/submissions",
  verifySupabaseAuth.required,
  getSubmissions
);

export default router;
