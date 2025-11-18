import { purchaseBook ,checkPurchase} from "../controllers/purchaseController.js";
import { verifySupabaseAuth } from "../middleware/authMiddleware.js";
import express from "express";

const router = express.Router();
router.post("/", verifySupabaseAuth, purchaseBook);
router.get("/check", verifySupabaseAuth, checkPurchase);


export default router;