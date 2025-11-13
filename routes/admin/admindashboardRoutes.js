import express from "express";
import { getAdminDashboard } from "../../controllers/admin/dashboardController.js";
import { verifySupabaseAuth } from "../../middleware/authMiddleware.js";
import {adminOnly} from "../../middleware/verifyAdminMiddleware.js";


const router = express.Router();

router.get("/dashboard",verifySupabaseAuth,adminOnly, getAdminDashboard);

export default router;
