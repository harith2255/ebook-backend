import express from "express";
import {
  getCurrentAffairs,
  incrementViews,
} from "../controllers/currentAffairsController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
const router = express.Router();

router.get("/",  verifySupabaseAuth.required, getCurrentAffairs);
router.post("/:id/view",  verifySupabaseAuth.required, incrementViews);

export default router;
