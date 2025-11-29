import express from "express";
import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";
import {
  getJobs,
  createJob,
  updateJob,
  deleteJob,
} from "../../controllers/admin/jobController.js";

const router = express.Router();

router.get("/", verifySupabaseAuth.required, adminOnly, getJobs);
router.post("/", verifySupabaseAuth.required, adminOnly, createJob);
router.put("/:id", verifySupabaseAuth.required, adminOnly, updateJob);
router.delete("/:id", verifySupabaseAuth.required, adminOnly, deleteJob);

export default router;
