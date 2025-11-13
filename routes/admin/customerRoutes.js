// routes/customerRoutes.js
import express from "express";
import { verifySupabaseAuth, adminOnly } from "../../middleware/authMiddleware.js";
import {
  listCustomers,
  suspendCustomer,
  activateCustomer,
  sendEmailToCustomer,
  getSubscriptionHistory,
  addSubscription,
  deleteCustomer
} from "../../controllers/admin/customerController.js";

const router = express.Router();

router.use(verifySupabaseAuth, adminOnly);

router.get("/", listCustomers);
router.post("/:id/suspend", suspendCustomer);
router.post("/:id/activate", activateCustomer);
router.post("/:id/email", sendEmailToCustomer);
router.get("/:id/subscriptions", getSubscriptionHistory);
router.post("/:id/subscriptions", addSubscription);
router.delete("/:id", deleteCustomer); // optional

export default router;
