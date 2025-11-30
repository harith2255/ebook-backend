// src/routes/admin/adminExamRoutes.js
import express from "express";
import multer from "multer";

import {
  listSubjects,
  uploadNote,
  createExam,
  uploadExamFile,
  listExams,
  attendExam,
  getExamSubmissions,
  gradeSubmission,
  getFolders,
  uploadUnified,
  deleteSubject,
  updateExam,
} from "../../controllers/admin/adminExamController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const upload = multer({ storage: multer.memoryStorage() });

const router = express.Router();

/* -------------------------------------------------------------------------- */
/*                               ADMIN ROUTES                                 */
/* -------------------------------------------------------------------------- */

/* 🔹 LIST SUBJECTS — MUST BE ABOVE "/" ROUTE */
router.get("/subjects", verifySupabaseAuth.required, adminOnly, listSubjects);

/* 🔹 GET ADMIN FOLDERS */
router.get("/folders", verifySupabaseAuth.required, adminOnly, getFolders);

/* 🔹 CREATE EXAM */
router.post("/", verifySupabaseAuth.required, adminOnly, createExam);

/* NOTE UPLOAD */
router.post(
  "/notes/upload",
  upload.single("file"),
  verifySupabaseAuth.required,
  adminOnly,
  uploadNote
);

/* EXAM FILE UPLOAD */
router.post(
  "/:id/upload-file",
  upload.single("file"),
  verifySupabaseAuth.required,
  adminOnly,
  uploadExamFile
);

/* UNIFIED UPLOAD */
router.post(
  "/upload",
  upload.single("file"),
  verifySupabaseAuth.required,
  adminOnly,
  uploadUnified
);

/* 🔹 DELETE SUBJECT */
router.delete(
  "/subject/:id",
  verifySupabaseAuth.required,
  adminOnly,
  deleteSubject
);

/* -------------------------------------------------------------------------- */
/*                                 USER ROUTES                                  */
/* -------------------------------------------------------------------------- */

/* 🔹 USER SUBMITS EXAM */
router.post(
  "/:id/attend",
  verifySupabaseAuth.required,
  upload.single("answer_file"),
  attendExam
);

/* -------------------------------------------------------------------------- */
/*                               ADMIN — SUBMISSIONS                           */
/* -------------------------------------------------------------------------- */

router.get(
  "/:id/submissions",
  verifySupabaseAuth.required,
  adminOnly,
  getExamSubmissions
);

router.post(
  "/submissions/:id/grade",
  verifySupabaseAuth.required,
  adminOnly,
  gradeSubmission
);

/* 🔹 UPDATE EXAM */
router.put("/:id", verifySupabaseAuth.required, adminOnly, updateExam);

/* -------------------------------------------------------------------------- */
/*                       LAST ROUTE — LIST EXAMS                               */
/* -------------------------------------------------------------------------- */

/* ❗ THIS **MUST BE AT THE END** or it breaks routing */
router.get("/", verifySupabaseAuth.required, listExams);

export default router;
