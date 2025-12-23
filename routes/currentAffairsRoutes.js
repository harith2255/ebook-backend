import express from "express";
import {
  getCurrentAffairs,
  incrementViews,
  getCurrentAffairsCategories,
} from "../controllers/currentAffairsController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
const router = express.Router();
router.get("/categories", verifySupabaseAuth.required, getCurrentAffairsCategories);

router.get("/",  verifySupabaseAuth.required, getCurrentAffairs);
router.post("/:id/view",  verifySupabaseAuth.required, incrementViews);

export default router;
