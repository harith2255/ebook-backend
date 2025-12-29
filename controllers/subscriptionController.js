import supabase from "../utils/supabaseClient.js";

/**
 * POST /api/subscriptions/upgrade
 * Body: { planId }
 * Protected - create/replace subscription + record revenue
 */
export const upgradeSubscription = async (req, res) => {
  try {
    const userId = req.user.id;
    const { planId } = req.body;

    if (!planId) {
      return res.status(400).json({ error: "planId required" });
    }


    // READ-ONLY SUSPENSION CHECK
const { data: profile } = await supabase
  .from("profiles")
  .select("account_status")
  .eq("id", userId)
  .single();

if (profile?.account_status === "suspended") {
  return res.status(403).json({
    error: "Your account is suspended. Read-only mode enabled.",
    read_only: true
  });
}


    // 1️⃣ Fetch selected plan
    const { data: plan, error: planErr } = await supabase
      .from("subscription_plans")
      .select("*")
      .eq("id", planId)
      .single();

    if (planErr) {
      console.error("subscription_plans error:", planErr);
      return res.status(400).json({ error: "Invalid planId" });
    }
    if (!plan) {
      return res.status(404).json({ error: "Plan not found" });
    }

    const price = Number(plan.price) || 0;

    // 2️⃣ Create payment transaction
    const { error: txErr } = await supabase
      .from("payments_transactions")
      .insert({
        user_id: userId,
        plan_id: plan.id,          // plan.id is numeric (bigint)
        amount: price,
        currency: "INR",
        method: "manual-test",
        status: "completed",
        description: `Purchase ${plan.name}`,
      });

    if (txErr) {
      console.error("payments_transactions error:", txErr);
      return res.status(500).json({ error: "Failed to create transaction" });
    }

    // 3️⃣ Record revenue
    // IMPORTANT:
    // - item_id (uuid) is NOT used for numeric plan ids
    // - store numeric plan id in old_item_id
    const { error: revErr } =await supabase.from("revenue").insert({
  user_id: userId,
  amount: price,
  item_type: "subscription",
  item_id: null,            // must be null
  old_item_id: plan.id,     // numeric
  payment_id: null,
  created_at: new Date().toISOString(),
});

    if (revErr) {
      console.error("revenue insert error:", revErr);
      // not fatal for user, but log it
    }

    // 4️⃣ Compute expiry date
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

    // 5️⃣ Deactivate old subscriptions
    const { error: deactivateErr } = await supabase
      .from("user_subscriptions")
      .update({ status: "expired" })
      .eq("user_id", userId)
      .eq("status", "active");

    if (deactivateErr) {
      console.error("user_subscriptions deactivate error:", deactivateErr);
      // not fatal, user still gets new active one
    }

    // 6️⃣ Create new active subscription
    const { data: newSub, error: subErr } = await supabase
      .from("user_subscriptions")
      .insert({
        user_id: userId,
        plan_id: plan.id, // same numeric id as in subscription_plans
        started_at: new Date().toISOString(),
        expires_at: expiresAt,
        status: "active",
      })
      .select()
      .single();

    if (subErr) {
      console.error("user_subscriptions insert error:", subErr);
      return res.status(500).json({ error: "Failed to create subscription" });
    }

    // 7️⃣ Return clean object
    return res.json({
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
    return res.status(500).json({ error: "Upgrade failed" });
  }
};

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
