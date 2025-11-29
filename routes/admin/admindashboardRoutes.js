import express from "express";
import { getAdminDashboard } from "../../controllers/admin/dashboardController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get(
  "/dashboard",
  verifySupabaseAuth.required,
  adminOnly,
  getAdminDashboard
);

export default router;
