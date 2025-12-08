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
  uploadMultipleExams,
  uploadMultipleNotes,
  deleteExamFile,deleteNote,
  createSubject,
} from "../../controllers/admin/adminExamController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const upload = multer({ storage: multer.memoryStorage() });


// multi-file upload (up to 20)
const uploadMulti = multer({
  storage: multer.memoryStorage(),
}).array("files", 20);

const router = express.Router();


/* -------------------------------------------------------------------------- */
/*                               ADMIN ROUTES                                 */
/* -------------------------------------------------------------------------- */
router.post("/subject", verifySupabaseAuth.required,adminOnly, createSubject);

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
// POST: upload multiple notes to existing subject
/* MULTI UPLOAD NOTES */
router.post(
  "/notes/upload-multiple",
  verifySupabaseAuth.required,
  adminOnly,
  uploadMulti,
  uploadMultipleNotes
);

/* MULTI UPLOAD EXAMS */
router.post(
  "/exams/upload-multiple",
  verifySupabaseAuth.required,
  adminOnly,
  uploadMulti,
  uploadMultipleExams
);
// DELETE NOTE
router.delete(
  "/notes/:id",
  verifySupabaseAuth.required,
  adminOnly,
  deleteNote
);

// DELETE EXAM FILE
router.delete(
  "/exams/:id",
  verifySupabaseAuth.required,
  adminOnly,
  deleteExamFile
);



/* 🔹 UPDATE EXAM */
router.put("/:id", verifySupabaseAuth.required, adminOnly, updateExam);

/* -------------------------------------------------------------------------- */
/*                       LAST ROUTE — LIST EXAMS                               */
/* -------------------------------------------------------------------------- */

/* ❗ THIS **MUST BE AT THE END** or it breaks routing */
router.get("/", verifySupabaseAuth.required, listExams);

export default router;
