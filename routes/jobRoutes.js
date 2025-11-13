import express from "express";
import { 
  getAllJobs,
  getFilteredJobs,
  saveJob,
  getSavedJobs,
  applyToJob
} from "../controllers/jobController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";

const router = express.Router();

// Public
router.get("/", getAllJobs);
router.get("/filter", getFilteredJobs);

// Protected
router.post("/save", verifySupabaseAuth, saveJob);
router.get("/saved", verifySupabaseAuth, getSavedJobs);
router.post("/apply", verifySupabaseAuth, applyToJob);




export default router;
