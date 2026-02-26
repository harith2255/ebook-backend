import supabase from "../utils/pgClient.js";

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
    if (!provider || !displayName)
      return res.status(400).json({ error: "Missing" });

    const { data, error } = await supabase
      .from("payment_methods")
      .insert({
        user_id: userId,
        provider,
        display_name: displayName,
        last4,
        expiry,
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
// controllers/paymentController.js (append)
export const setDefaultPaymentMethod = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // clear existing defaults
    const { error: clearErr } = await supabase
      .from("payment_methods")
      .update({ is_default: false })
      .eq("user_id", userId);

    if (clearErr) throw clearErr;

    // set chosen as default
    const { data, error } = await supabase
      .from("payment_methods")
      .update({ is_default: true })
      .eq("id", id)
      .eq("user_id", userId)
      .select()
      .single();

    if (error) throw error;
    res.json({ success: true, method: data });
  } catch (err) {
    console.error("setDefaultPaymentMethod error:", err.message || err);
    res.status(500).json({ error: "Failed to set default method" });
  }
};
export const deletePaymentMethodById = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // ensure method belongs to user
    const { data: existing, error: findErr } = await supabase
      .from("payment_methods")
      .select("*")
      .eq("id", id)
      .eq("user_id", userId)
      .maybeSingle();

    if (findErr) throw findErr;
    if (!existing) return res.status(404).json({ error: "Method not found" });
    if (existing.is_default)
      return res.status(400).json({ error: "Cannot delete default method" });

    const { error } = await supabase
      .from("payment_methods")
      .delete()
      .eq("id", id)
      .eq("user_id", userId);

    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    console.error("deletePaymentMethod error:", err.message || err);
    res.status(500).json({ error: "Failed to delete method" });
  }
};
