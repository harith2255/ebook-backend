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
      .order("started_at", { ascending: false }) // newest first
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error("SUPABASE ERROR:", error);
      return res.status(500).json({
        error: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
      });
    }

    if (!data) return res.json(null);

    // flatten structure for frontend
    const active = {
      id: data.plan.id,
      name: data.plan.name,
      price: data.plan.price,
      period: data.plan.period,
      renewsOn: data.expires_at,
    };

    res.json(active);

  } catch (err) {
    console.error("getActiveSubscription error:", err.message || err);
    res.status(500).json({ error: "Failed to fetch subscription" });
  }
};


/**
 * POST /api/subscriptions/upgrade
 * Body: { planId }
 * Protected - create/replace subscription + record revenue
 */
export const upgradeSubscription = async (req, res) => {
  try {
    const userId = req.user.id;
    const { planId } = req.body;

    if (!planId) return res.status(400).json({ error: "planId required" });

    // fetch selected plan
    const { data: plan, error: planErr } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("id", planId)
      .single();

    if (planErr) throw planErr;
    if (!plan) return res.status(404).json({ error: "Plan not found" });

    const price = Number(plan.price) || 0;

    // 1️⃣ create payment transaction
    const { error: txErr } = await supabase
      .from("payments_transactions")
      .insert({
        user_id: userId,
        plan_id: planId,
        amount: price,
        currency: "INR",
        method: "manual-test",
        status: "completed",
        description: `Purchase ${plan.name}`,
      });

    if (txErr) throw txErr;

    // ⭐️ 2️⃣ record revenue
    const { error: revErr } = await supabase
      .from("revenue")
      .insert({
        user_id: userId,
        amount: price,
        item_type: "subscription",
        item_id: plan.id,
      });

    if (revErr) throw revErr;


    // 3️⃣ compute expiry date (⚠️ avoid mutating date)
    const now = new Date();
    let expiresAt;

    if (plan.period === "monthly") {
      const future = new Date(now);
      future.setMonth(future.getMonth() + 1);
      expiresAt = future.toISOString();
    } else {
      const future = new Date(now);
      future.setFullYear(future.getFullYear() + 1);
      expiresAt = future.toISOString();
    }


    // 4️⃣ deactivate old subscriptions
    await supabase
      .from("user_subscriptions")
      .update({ status: "expired" })
      .eq("user_id", userId)
      .eq("status", "active");


    // 5️⃣ create new active subscription
    const { data: newSub, error: subErr } = await supabase
      .from("user_subscriptions")
      .insert({
        user_id: userId,
        plan_id: planId,
        started_at: new Date().toISOString(),
        expires_at: expiresAt,
        status: "active",
      })
      .select()
      .single();

    if (subErr) throw subErr;


    // 6️⃣ return clean object to frontend
    res.json({
      success: true,
      subscription: {
        id: plan.id,
        name: plan.name,
        price: plan.price,
        period: plan.period,
        renewsOn: expiresAt,
      },
    });

  } catch (err) {
    console.error("upgradeSubscription error:", err.message || err);
    res.status(500).json({ error: "Upgrade failed" });
  }
};


/**
 * GET /api/subscriptions/:id
 * Public: get single plan
 */
export const getSinglePlan = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;

    if (!data) {
      return res.status(404).json({ error: "Subscription plan not found" });
    }

    res.json({
      id: data.id,
      name: data.name,
      price: data.price,
      period: data.period,
      description: data.description || "",
      features: data.features || [],
    });

  } catch (err) {
    console.error("getSinglePlan error:", err.message || err);
    res.status(500).json({ error: "Failed to load subscription plan" });
  }
};


/**
 * POST /api/subscriptions/cancel
 * Protected: cancel subscription
 */
export const cancelSubscription = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: activeSub, error: activeErr } = await supabase
      .from("user_subscriptions")
      .select("*")
      .eq("user_id", userId)
      .eq("status", "active")
      .maybeSingle();

    if (activeErr) throw activeErr;

    if (!activeSub) {
      return res.status(400).json({ error: "No active subscription found" });
    }

    // mark canceled (user keeps access until expiry)
    const { error: updateErr } = await supabase
      .from("user_subscriptions")
      .update({ status: "canceled" })
      .eq("id", activeSub.id);

    if (updateErr) throw updateErr;

    // optional: log transaction
    await supabase.from("payments_transactions").insert({
      user_id: userId,
      plan_id: activeSub.plan_id,
      amount: 0,
      currency: "INR",
      method: "system",
      status: "completed",
      description: "Subscription canceled",
    });

    res.json({
      success: true,
      message: "Subscription canceled successfully",
      expiresAt: activeSub.expires_at,
    });

  } catch (err) {
    console.error("cancelSubscription error:", err.message || err);
    res.status(500).json({ error: "Failed to cancel subscription" });
  }
};
