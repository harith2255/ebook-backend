import express from "express";
import { listContent } from "../controllers/admin/contentController.js";

const router = express.Router();

// PUBLIC — NO ADMIN CHECK
router.get("/", listContent);

export default router;
