// routes/customerRoutes.js
import express from "express";
import {
  verifySupabaseAuth,
  adminOnly,
} from "../../middleware/authMiddleware.js";

import {
  listCustomers,
  suspendCustomer,
  activateCustomer,
  getSubscriptionHistory,
  addSubscription,
  deleteCustomer,
  sendNotificationToCustomer,
} from "../../controllers/admin/customerController.js";

const router = express.Router();

// Admin-protected routes
router.use(verifySupabaseAuth.required, adminOnly);

router.get("/", listCustomers);
router.post("/:id/suspend", suspendCustomer);
router.post("/:id/activate", activateCustomer);
router.post("/:id/notify", sendNotificationToCustomer);
router.get("/:id/subscriptions", getSubscriptionHistory);
router.post("/:id/subscriptions", addSubscription);
router.delete("/:id", deleteCustomer);

export default router;
