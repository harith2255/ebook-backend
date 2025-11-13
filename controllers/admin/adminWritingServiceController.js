import supabase from "../../utils/supabaseClient.js";

/* ✅ Get all writing orders */
export const getAllOrders = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*, users(email, name)")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ✅ Get only pending orders */
export const getPendingOrders = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*")
    .eq("status", "Pending")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ✅ Admin accepts a writing order */
export const acceptOrder = async (req, res) => {
  try {
    const adminId = req.user.id; // ensure req.user is admin
    const { id } = req.params;

    const { data: order, error: fetchError } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("id", id)
      .single();

    if (fetchError || !order)
      return res.status(404).json({ error: "Order not found" });

    // ✅ Update order status and assign admin
    const { error: updateError } = await supabase
      .from("writing_orders")
      .update({
        status: "In Progress",
        author_id: adminId,
        accepted_at: new Date(),
      })
      .eq("id", id);

    if (updateError) throw updateError;

    // ✅ Notify user
    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Accepted",
        message: `Your writing request (#${id}) has been accepted and is now being worked on.`,
        created_at: new Date(),
        is_read: false,
      },
    ]);

    res.json({ message: "Order accepted successfully!" });
  } catch (err) {
    console.error("Accept order error:", err.message);
    res.status(500).json({ error: "Error accepting order" });
  }
};

/* ✅ Admin uploads completed work or notes */
export const completeOrder = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;
    const { notes_url, message } = req.body;

    // Check if order exists and belongs to admin
    const { data: order, error: fetchError } = await supabase
      .from("writing_orders")
      .select("id, author_id, user_id")
      .eq("id", id)
      .single();

    if (fetchError || !order)
      return res.status(404).json({ error: "Order not found" });

    if (order.author_id !== adminId)
      return res
        .status(403)
        .json({ error: "Unauthorized: You are not assigned to this order" });

    // ✅ Update order status and attach notes file
    const { error: updateError } = await supabase
      .from("writing_orders")
      .update({
        status: "Completed",
        completed_at: new Date(),
        notes_url, // could be a Supabase Storage file URL or other upload
      })
      .eq("id", id);

    if (updateError) throw updateError;

    // ✅ Optionally log completion message in feedback/messages
    if (message) {
      await supabase.from("writing_feedback").insert([
        {
          user_id: order.user_id,
          order_id: id,
          writer_name: "Admin",
          message,
        },
      ]);
    }

    // ✅ Notify user about completion
    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Completed",
        message: `Your requested notes or assessment (#${id}) is now ready. Please check your dashboard to download it.`,
        created_at: new Date(),
        is_read: false,
      },
    ]);

    res.json({ message: "Order marked as completed and user notified!" });
  } catch (err) {
    console.error("Complete order error:", err.message);
    res.status(500).json({ error: "Error completing order" });
  }
};

/* ✅ Reject order (if invalid or unclear) */
export const rejectOrder = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;
    const { reason } = req.body;

    const { data: order, error: fetchError } = await supabase
      .from("writing_orders")
      .select("id, user_id")
      .eq("id", id)
      .single();

    if (fetchError || !order)
      return res.status(404).json({ error: "Order not found" });

    // Update status
    const { error: updateError } = await supabase
      .from("writing_orders")
      .update({
        status: "Rejected",
        rejection_reason: reason || "Not specified",
        rejected_at: new Date(),
      })
      .eq("id", id);

    if (updateError) throw updateError;

    // Notify user
    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Rejected",
        message: `Your writing request (#${id}) was rejected by admin. Reason: ${
          reason || "Not specified"
        }.`,
        created_at: new Date(),
        is_read: false,
      },
    ]);

    res.json({ message: "Order rejected and user notified" });
  } catch (err) {
    console.error("Reject order error:", err.message);
    res.status(500).json({ error: "Error rejecting order" });
  }
};
