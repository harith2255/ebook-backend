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
const upload = multer(); // ✅ handle file upload in memory

// Upload & publish
router.post(
  "/upload",
  upload.single("file"),  // ⬅ REQUIRED
  uploadContent
);


// List content
router.get("/", verifySupabaseAuth, adminOnly, listContent);

// Delete content
router.delete("/:type/:id", verifySupabaseAuth, adminOnly, deleteContent);
// edit
router.put("/:type/:id",verifySupabaseAuth,adminOnly,upload.single("file"), editContent
);


export default router;
