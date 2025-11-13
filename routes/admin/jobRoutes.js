import express from "express";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";
import {
  getJobs,
  createJob,
  updateJob,
  deleteJob
} from "../../controllers/admin/jobController.js";

const router = express.Router();

router.get("/", verifySupabaseAuth, adminOnly, getJobs);
router.post("/", verifySupabaseAuth, adminOnly, createJob);
router.put("/:id", verifySupabaseAuth, adminOnly, updateJob);
router.delete("/:id", verifySupabaseAuth, adminOnly, deleteJob);

export default router;
