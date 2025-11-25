import express from "express";
import {
  getAllOrders,
  getPendingOrders,
  acceptOrder,
  completeOrder,
  rejectOrder,
  adminReply
} from "../../controllers/admin/adminWritingServiceController.js";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";

const router = express.Router();

// Always: verifySupabaseAuth → adminOnly → controller
router.get("/orders", verifySupabaseAuth, adminOnly, getAllOrders);
router.get("/orders/pending", verifySupabaseAuth, adminOnly, getPendingOrders);
router.put("/orders/:id/accept", verifySupabaseAuth, adminOnly, acceptOrder);
router.put("/orders/:id/complete", verifySupabaseAuth, adminOnly, completeOrder);
router.put("/orders/:id/reject", verifySupabaseAuth, adminOnly, rejectOrder);


import { uploadWritingFile } from "../../controllers/admin/adminWritingServiceController.js";
import multer from "multer";

const upload = multer({ storage: multer.memoryStorage() });


router.post(
  "/upload",
  verifySupabaseAuth,
  adminOnly,
  upload.single("file"),      // ← THIS WAS MISSING
  uploadWritingFile
);


router.post(
  "/orders/reply",
  verifySupabaseAuth,
  adminOnly,
  adminReply
);


export default router;
