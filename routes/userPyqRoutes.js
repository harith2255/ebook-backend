import express from "express";
import {
  getSubjects,
  getYearFolders,
  getPapers,
} from "../controllers/userPyqController.js";

const router = express.Router();

// USER READ-ONLY ROUTES
router.get("/subjects", getSubjects);
router.get("/subjects/:subjectId/folders", getYearFolders);
router.get("/subjects/:subjectId/papers/:start/:end", getPapers);

export default router;
