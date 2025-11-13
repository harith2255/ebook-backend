import express from "express";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import { getDashboardData } from "../controllers/dashBoardController.js";

const router = express.Router();

// Require login
router.use(verifySupabaseAuth);

// GET dashboard info
router.get("/", getDashboardData);

export default router;
