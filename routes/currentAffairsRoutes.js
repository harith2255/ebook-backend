import express from "express";
import {
  getCurrentAffairs,
  incrementViews,
} from "../controllers/currentAffairsController.js";

const router = express.Router();

router.get("/", getCurrentAffairs);
router.post("/:id/view", incrementViews);

export default router;
