import supabase from "../utils/supabaseClient.js";

// ✅ Get all available services
export const getServices = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_services")
    .select("*")
    .order("id", { ascending: true });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Place a new order
export const placeOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      title,
      type,
      subject_area,
      academic_level,
      pages,
      deadline,
      total_price,
    } = req.body;

    const { data, error } = await supabase
      .from("writing_orders")
      .insert([
        {
          user_id: userId,
          title,
          type,
          subject_area,
          academic_level,
          pages,
          deadline,
          total_price,
          status: "Pending",
        },
      ])
      .select();

    if (error) throw error;

    res.json({ message: "Order placed successfully!", order: data[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Get active orders
export const getActiveOrders = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*")
    .eq("user_id", userId)
    .in("status", ["In Progress", "Draft Review"]);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Get completed orders
export const getCompletedOrders = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "Completed");

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};



/**
 * ✅ Update order and notify assigned author
 */
export const updateOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { deadline, additional_notes } = req.body;

    // ✅ Fetch the order first to verify ownership and get author_id
    const { data: order, error: fetchError } = await supabase
      .from("writing_orders")
      .select("id, user_id, author_id, deadline")
      .eq("id", id)
      .single();

    if (fetchError || !order)
      return res.status(404).json({ error: "Order not found" });

    if (order.user_id !== userId)
      return res.status(403).json({ error: "Unauthorized: Not your order" });

    // ✅ Update order details
    const { error: updateError } = await supabase
      .from("writing_orders")
      .update({
        deadline,
        additional_notes,
        updated_at: new Date(),
      })
      .eq("id", id);

    if (updateError)
      return res.status(400).json({ error: updateError.message });

    // ✅ Send notification to the author
    const notificationTitle = "Order Updated";
    const notificationMessage = `The order #${id} has been updated by the client. 
New deadline: ${deadline || "unchanged"}.`;

    const { error: notifyError } = await supabase
      .from("user_notifications")
      .insert([
        {
          user_id: order.author_id,
          title: notificationTitle,
          message: notificationMessage,
          created_at: new Date(),
          is_read: false,
        },
      ]);

    if (notifyError)
      console.error("Notification error:", notifyError.message);

    // ✅ (Optional) You can also send a direct chat message if you have a chat table
    // await supabase.from("messages").insert([
    //   {
    //     sender_id: userId,
    //     receiver_id: order.author_id,
    //     content: `Your assigned order (#${id}) has been updated.`,
    //     created_at: new Date(),
    //   },
    // ]);

    res.json({ message: "Order updated and author notified" });
  } catch (err) {
    console.error("Order update error:", err.message);
    res.status(500).json({ error: "Server error updating order" });
  }
};


// ✅ Send feedback / message to writer
export const sendFeedback = async (req, res) => {
  const userId = req.user.id;
  const { order_id, writer_name, message } = req.body;

  const { error } = await supabase.from("writing_feedback").insert([
    {
      user_id: userId,
      order_id,
      writer_name,
      message,
    },
  ]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Feedback sent successfully" });
};

// ✅ Get messages for an order
export const getFeedbackForOrder = async (req, res) => {
  const { order_id } = req.params;

  const { data, error } = await supabase
    .from("writing_feedback")
    .select("*")
    .eq("order_id", order_id)
    .order("created_at", { ascending: true });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};
export const updateOrderStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  const allowed = ["Pending", "In Progress", "Draft Review", "Completed"];

  if (!allowed.includes(status)) {
    return res.status(400).json({ error: "Invalid status" });
  }

  const { error } = await supabase
    .from("writing_orders")
    .update({ status })
    .eq("id", id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Status updated successfully" });
};
export const assignWriter = async (req, res) => {
  const { order_id, author_id } = req.body;

  const { error } = await supabase
    .from("writing_orders")
    .update({ author_id })
    .eq("id", order_id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Writer assigned" });
};
