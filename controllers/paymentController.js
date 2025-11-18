import supabase from "../utils/supabaseClient.js";

/**
 * GET /api/payments/transactions
 * Protected - return recent transactions for user
 */
export const getTransactions = async (req, res) => {
  try {
    const userId = req.user.id;
    const { data, error } = await supabase
      .from("payments_transactions")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("getTransactions error:", err.message || err);
    res.status(500).json({ error: "Failed to load transactions" });
  }
};

/**
 * GET /api/payments/methods
 * Protected - list saved payment methods
 */
export const getPaymentMethods = async (req, res) => {
  try {
    const userId = req.user.id;
    const { data, error } = await supabase
      .from("payment_methods")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("getPaymentMethods error:", err.message || err);
    res.status(500).json({ error: "Failed to load payment methods" });
  }
};

/**
 * POST /api/payments/methods
 * Protected - add a method (this is a simple demo; in production you'd store tokens from Stripe/Razorpay)
 * Body: { provider, displayName, last4, expiry }
 */
export const addPaymentMethod = async (req, res) => {
  try {
    const userId = req.user.id;
    const { provider, displayName, last4, expiry } = req.body;
    if (!provider || !displayName) return res.status(400).json({ error: "Missing" });

    const { data, error } = await supabase
      .from("payment_methods")
      .insert({
        user_id: userId,
        provider,
        display_name: displayName,
        last4,
        expiry
      })
      .select()
      .single();

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("addPaymentMethod error:", err.message || err);
    res.status(500).json({ error: "Failed to add method" });
  }
};
