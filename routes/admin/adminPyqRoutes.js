import express from "express";
import { upload } from "../../middleware/uploadPdf.js";
import {
  uploadPYQ,
  getSubjects,
  getPapersBySubject,
  deletePaper,
  deleteSubject,
} from "../../controllers/admin/pyqController.js";

const router = express.Router();

router.post(
  "/upload",
  upload.fields([
    { name: "question", maxCount: 1 },
    { name: "answer", maxCount: 1 },
  ]),
  uploadPYQ
);

router.get("/subjects", getSubjects);
router.get("/subjects/:subjectId/papers", getPapersBySubject);
router.delete("/paper/:id", deletePaper);
router.delete("/subject/:id", deleteSubject);

export default router;
