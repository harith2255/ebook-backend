import express from "express";
import {
  getAllOrders,
  getPendingOrders,
  acceptOrder,
  completeOrder,
  rejectOrder,
  adminReply,
  uploadWritingFile,
  markAsRead,
  getInterviewMaterials,
  createInterviewMaterial,
  updateInterviewMaterial,
  deleteInterviewMaterial,
  uploadInterviewFile,

} from "../../controllers/admin/adminWritingServiceController.js";

import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";
import multer from "multer";

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

// Always: verifySupabaseAuth → adminOnly → controller

router.get("/orders", verifySupabaseAuth.required, adminOnly, getAllOrders);

router.get(
  "/orders/pending",
  verifySupabaseAuth.required,
  adminOnly,
  getPendingOrders
);

router.put(
  "/orders/:id/accept",
  verifySupabaseAuth.required,
  adminOnly,
  acceptOrder
);

router.put(
  "/orders/:id/complete",
  verifySupabaseAuth.required,
  adminOnly,
  completeOrder
);

router.put(
  "/orders/:id/reject",
  verifySupabaseAuth.required,
  adminOnly,
  rejectOrder
);
router.put("/mark-read/:order_id", verifySupabaseAuth.required, markAsRead);


// Upload files for writing service
router.post(
  "/upload",
  verifySupabaseAuth.required,
  adminOnly,
  upload.single("file"),
  uploadWritingFile
);

// Admin replies to user
router.post(
  "/orders/reply",
  verifySupabaseAuth.required,
  adminOnly,
  adminReply
);


/* ================================
   INTERVIEW MATERIALS (ADMIN)
================================ */

router.get(
  "/interview-materials",
  verifySupabaseAuth.required,
  adminOnly,
  getInterviewMaterials
);

router.post(
  "/interview-materials",
  verifySupabaseAuth.required,
  adminOnly,
  createInterviewMaterial
);

router.put(
  "/interview-materials/:id",
  verifySupabaseAuth.required,
  adminOnly,
  updateInterviewMaterial
);

router.delete(
  "/interview-materials/:id",
  verifySupabaseAuth.required,
  adminOnly,
  deleteInterviewMaterial
);

router.post(
  "/interview-materials/upload",
  verifySupabaseAuth.required,
  adminOnly,
  upload.single("file"),
  uploadInterviewFile
);


export default router;
