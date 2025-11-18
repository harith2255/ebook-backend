import supabase from "../utils/supabaseClient.js";

/**
 * GET /api/subscriptions/plans
 * Public (returns all plans)
 */
export const getPlans = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("subscription_plans")
      .select("*")
      .order("price", { ascending: true });

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("getPlans error:", err.message || err);
    res.status(500).json({ error: "Failed to load plans" });
  }
};

/**
 * GET /api/subscriptions/active
 * Protected - returns current user's active subscription
 */
export const getActiveSubscription = async (req, res) => {
  try {
    const userId = req.user.id;
    const { data, error } = await supabase
      .from("user_subscriptions")
      .select("*, plan:subscription_plans(*)")
      .eq("user_id", userId)
      .eq("status", "active")
      .order("started_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) throw error;
    res.json(data || null);
  } catch (err) {
    console.error("getActiveSubscription error:", err.message || err);
    res.status(500).json({ error: "Failed to fetch subscription" });
  }
};

/**
 * POST /api/subscriptions/upgrade
 * Body: { planId }
 * Protected - simulate payment + create/replace subscription
 */
export const upgradeSubscription = async (req, res) => {
  try {
    const userId = req.user.id;
    const { planId } = req.body;

    if (!planId) return res.status(400).json({ error: "planId required" });

    // fetch plan
    const { data: plan, error: planErr } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("id", planId)
      .single();

    if (planErr) throw planErr;

    // simulate payment: create transaction
    const txAmount = plan.price;
   const { error: txErr } = await supabase
  .from("payments_transactions")
  .insert({
    user_id: userId,
    plan_id: planId,
    amount: txAmount,
    currency: "INR",            // ✔ REQUIRED
    method: "manual-test",
    status: "completed",
    description: `Purchase ${plan.name}`
  });



    if (txErr) throw txErr;

    // compute expiry date
    const now = new Date();
    let expiresAt = null;
    if (plan.period === "monthly") {
      expiresAt = new Date(now.setMonth(now.getMonth() + 1)).toISOString();
    } else {
      expiresAt = new Date(now.setFullYear(now.getFullYear() + 1)).toISOString();
    }

    // insert user subscription (deactivate old active subscriptions)
    await supabase
      .from("user_subscriptions")
      .update({ status: "expired" })
      .eq("user_id", userId)
      .eq("status", "active");

    const { data: newSub, error: subErr } = await supabase
      .from("user_subscriptions")
      .insert({
        user_id: userId,
        plan_id: planId,
        started_at: new Date().toISOString(),
        expires_at: expiresAt,
        status: "active"
      })
      .select()
      .single();

    if (subErr) throw subErr;

    res.json({ success: true, subscription: newSub });
  } catch (err) {
    console.error("upgradeSubscription error:", err.message || err);
    res.status(500).json({ error: "Upgrade failed" });
  }
};
