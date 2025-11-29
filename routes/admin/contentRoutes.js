import express from "express";
import multer from "multer";
import {
  uploadContent,
  listContent,
  deleteContent,
  editContent,
} from "../../controllers/admin/contentController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();
const upload = multer();

// UPLOAD EPUB / PDF + COVER
router.post(
  "/upload",
  verifySupabaseAuth.required, // 🔥 MUST COME FIRST
  adminOnly, // 🔥 MUST COME SECOND
  upload.fields([
    { name: "file", maxCount: 1 },
    { name: "cover", maxCount: 1 },
  ]),
  uploadContent
);

// EDIT CONTENT
router.put(
  "/:type/:id",
  verifySupabaseAuth.required,
  adminOnly,
  upload.fields([
    { name: "file", maxCount: 1 },
    { name: "cover", maxCount: 1 },
  ]),
  editContent
);

// DELETE – no multer required
router.delete(
  "/:type/:id",
  verifySupabaseAuth.required,
  adminOnly,
  deleteContent
);

// LIST CONTENT
router.get("/", verifySupabaseAuth.required, adminOnly, listContent);

export default router;
