import supabase from "../utils/supabaseClient.js";

/* =====================================================
   GET ALL WRITING SERVICES
===================================================== */
export const getServices = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_services")
    .select("*")
    .order("id", { ascending: true });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* =====================================================
   PLACE A NEW ORDER — NO safeDate, uses raw deadline
===================================================== */
export const placeOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const userName = req.user.user_metadata?.full_name || req.user.email;

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
          user_name: userName,
          title,
          type,
          subject_area,
          academic_level,
          pages,
          deadline,      // <-- RAW VALUE, NO safeDate
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

/* =====================================================
   GET ACTIVE ORDERS
===================================================== */
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

/* =====================================================
   GET COMPLETED ORDERS
===================================================== */
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

/* =====================================================
   GET ORDER BY ID (User can view final_text + files)
===================================================== */
export const getOrderById = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("id", id)
      .eq("user_id", userId)
      .single();

    if (error) throw error;

    res.json(data);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* =====================================================
   UPDATE ORDER (edit deadline + notes)
===================================================== */
export const updateOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const updatedBy = req.user.user_metadata?.full_name || req.user.email;

    const { id } = req.params;
    const { deadline, additional_notes } = req.body;

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, author_id")
      .eq("id", id)
      .single();

    if (error || !order)
      return res.status(404).json({ error: "Order not found" });

    if (order.user_id !== userId)
      return res.status(403).json({ error: "Unauthorized" });

    await supabase
      .from("writing_orders")
      .update({
        deadline,     // <-- RAW VALUE
        additional_notes,
        updated_by: updatedBy,
        updated_at: new Date(),
      })
      .eq("id", id);

    // notify writer
    await supabase.from("user_notifications").insert([
      {
        user_id: order.author_id,
        title: "Order Updated",
        message: `Order #${id} updated by ${updatedBy}.`,
        created_at: new Date(),
      },
    ]);

    res.json({ message: "Order updated & writer notified" });

  } catch (err) {
    res.status(500).json({ error: "Server error updating order" });
  }
};

/* =====================================================
   SEND FEEDBACK / MESSAGE
===================================================== */
export const sendFeedback = async (req, res) => {
  const userId = req.user.id;
  const userName = req.user.user_metadata?.full_name || req.user.email;

  const { order_id, writer_name, message } = req.body;

  const { error } = await supabase.from("writing_feedback").insert([
    {
      user_id: userId,
      user_name: userName,
      order_id,
      writer_name,
      message,
      created_at: new Date(),
    },
  ]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Feedback sent successfully" });
};

/* =====================================================
   GET FEEDBACK FOR ORDER
===================================================== */
export const getFeedbackForOrder = async (req, res) => {
  const { order_id } = req.params;

  const { data, error } = await supabase
    .from("writing_feedback")
    .select("id, message, writer_name, user_name, created_at")
    .eq("order_id", order_id)
    .order("created_at", { ascending: true });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};
