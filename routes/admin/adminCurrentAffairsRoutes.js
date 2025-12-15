import express from "express";
import { uploadImage } from "../../middleware/uploadImage.js";
import {
  getArticles,
  createArticle,
  updateArticle,
  deleteArticle,
} from "../../controllers/admin/adminCurrentAffairs.js";

const router = express.Router();

router.get("/", getArticles);
router.post("/", uploadImage.single("image"), createArticle);
router.put("/:id", uploadImage.single("image"), updateArticle);
router.delete("/:id", deleteArticle);

export default router;
