import express from "express";
import {
  getAllJobs,
  getFilteredJobs,
  saveJob,
  getSavedJobs,
  applyToJob,
} from "../controllers/jobController.js";

import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// ----- PUBLIC ROUTES -----
router.get("/", getAllJobs);
router.get("/filter", getFilteredJobs);

// ----- PROTECTED ROUTES -----
router.post("/save", verifySupabaseAuth.required, saveJob);
router.get("/saved", verifySupabaseAuth.required, getSavedJobs);
router.post("/apply", verifySupabaseAuth.required, applyToJob);

export default router;
