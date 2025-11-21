import express from "express";
import multer from "multer";
import {
  uploadContent,
  listContent,
  deleteContent,
  editContent,
} from "../../controllers/admin/contentController.js";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();
const upload = multer();

// UPLOAD EPUB / PDF + COVER
router.post(
  "/upload",
  verifySupabaseAuth,   // 🔥 MUST COME FIRST
  adminOnly,            // 🔥 MUST COME SECOND
  upload.fields([
    { name: "file", maxCount: 1 },
    { name: "cover", maxCount: 1 }
  ]),
  uploadContent
);


// EDIT CONTENT
router.put(
  "/:type/:id",
  upload.fields([
    { name: "file", maxCount: 1 },
    { name: "cover", maxCount: 1 }
  ]),
  verifySupabaseAuth,
  adminOnly,
  editContent
);

// DELETE – no multer here ever
router.delete(
  "/:type/:id",
  verifySupabaseAuth,
  adminOnly,
  deleteContent
);

// LIST
router.get(
  "/",
  verifySupabaseAuth,
  adminOnly,
  listContent
);

export default router;
