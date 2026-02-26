import crypto from "crypto";
import Razorpay from "razorpay";
import supabase from "../utils/pgClient.js";
import { unifiedPurchase } from "./purchaseController.js";

let razorpay;
try {
  if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
    razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID,
      key_secret: process.env.RAZORPAY_KEY_SECRET,
    });
  } else {
    console.warn("⚠️ RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET is missing. Payments won't work.");
  }
} catch (err) {
  console.error("⚠️ Failed to initialize Razorpay:", err.message);
}

/* =====================================================
   CREATE RAZORPAY ORDER
===================================================== */
export const createRazorpayOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { amount } = req.body;

    console.log("🧪 createRazorpayOrder called", {
      userId,
      amount,
      keyLoaded: !!process.env.RAZORPAY_KEY_ID,
      secretLoaded: !!process.env.RAZORPAY_KEY_SECRET,
    });

    if (!amount || amount <= 0) {
      console.warn("❌ Invalid amount:", amount);
      return res.status(400).json({ error: "Invalid amount" });
    }

    if (!razorpay) {
      console.error("❌ Razorpay not properly initialized. Check environment variables.");
      return res.status(500).json({ error: "Payment gateway is currently unavailable" });
    }

    const order = await razorpay.orders.create({
      amount: Math.round(amount * 100), // paise
      currency: "INR",
      receipt: `receipt_${Date.now()}`,
    });

    console.log("✅ Razorpay order created:", order.id);

    const { error: txErr } = await supabase
      .from("payments_transactions")
      .insert({
        user_id: userId,
        method: "razorpay",
        amount,
       external_ref: order.id, 
        status: "created",
      });

    if (txErr) {
      console.error("❌ payments_transactions insert failed:", txErr);
      return res.status(500).json({ error: "Transaction insert failed" });
    }

    return res.json(order);

  } catch (error) {
    console.error("🔥 createRazorpayOrder ERROR:", error);
    return res.status(500).json({
      error: error?.error?.description || error.message,
    });
  }
};

/* =====================================================
   VERIFY RAZORPAY PAYMENT
===================================================== */
export const verifyRazorpayPayment = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      items,
    } = req.body;

    console.log("🧪 verifyRazorpayPayment called", {
      userId,
      razorpay_order_id,
      razorpay_payment_id,
      hasItems: Array.isArray(items),
    });

    if (
      !razorpay_order_id ||
      !razorpay_payment_id ||
      !razorpay_signature
    ) {
      console.warn("❌ Missing Razorpay fields");
      return res.status(400).json({ error: "Missing Razorpay fields" });
    }

    if (!Array.isArray(items) || items.length === 0) {
      console.warn("❌ No purchase items provided");
      return res.status(400).json({ error: "No purchase items" });
    }

    /* ---------- 1️⃣ Fetch transaction first ---------- */
    const { data: tx, error: txFindErr } = await supabase
      .from("payments_transactions")
      .select("*")
      .eq("external_ref", razorpay_order_id)

      .eq("user_id", userId)
      .single();

    if (txFindErr || !tx) {
      console.error("❌ Transaction not found:", txFindErr);
      return res.status(404).json({ error: "Transaction not found" });
    }

    if (tx.status === "paid") {
      console.warn("⚠️ Duplicate payment verification attempt");
      return res.status(409).json({ error: "Payment already verified" });
    }

    /* ---------- 2️⃣ Verify signature ---------- */
    const body = `${razorpay_order_id}|${razorpay_payment_id}`;

    const expectedSignature = crypto
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest("hex");

    if (expectedSignature !== razorpay_signature) {
      console.error("❌ Signature mismatch", {
        expectedSignature,
        razorpay_signature,
      });
      return res.status(400).json({ error: "Invalid signature" });
    }

    console.log("✅ Razorpay signature verified");

    /* ---------- 3️⃣ Update transaction ---------- */
    const { error: txUpdateErr } = await supabase
      .from("payments_transactions")
      .update({
        payment_id: razorpay_payment_id,
        status: "paid",
        updated_at: new Date().toISOString(),
      })
      .eq("id", tx.id);

    if (txUpdateErr) {
      console.error("❌ Transaction update failed:", txUpdateErr);
      return res.status(500).json({ error: "Failed to update transaction" });
    }

    /* ---------- 4️⃣ Trigger business logic ---------- */
    req.body = { 
      items,
      payment: { payment_id: razorpay_payment_id }
    };
    return unifiedPurchase(req, res);

  } catch (error) {
    console.error("🔥 verifyRazorpayPayment ERROR:", error);
    return res.status(500).json({ error: "Payment verification failed" });
  }
};
