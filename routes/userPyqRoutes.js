import express from "express";
import {
  getSubjects,
  getYearFolders,
  getPapers,
} from "../controllers/userPyqController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// 🔐 USER AUTH REQUIRED (READ-ONLY)
router.use(verifySupabaseAuth.required);

router.get("/subjects", getSubjects);
router.get("/subjects/:subjectId/folders", getYearFolders);
router.get("/subjects/:subjectId/papers/:start/:end", getPapers);

export default router;
