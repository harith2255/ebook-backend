import supabase from "../../utils/supabaseClient.js";

/* ===============================
   GET ALL ORDERS
=============================== */
export const getAllOrders = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ===============================
   GET ONLY PENDING ORDERS
=============================== */
export const getPendingOrders = async (req, res) => {
  const { data, error } = await supabase
    .from("writing_orders")
    .select("*")
    .eq("status", "Pending")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ===============================
   ADMIN ACCEPTS ORDER (Admin = Writer)
=============================== */
export const acceptOrder = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;

    const { data: order } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", id)
      .single();

    if (!order) return res.status(404).json({ error: "Order not found" });

    const { error } = await supabase
      .from("writing_orders")
      .update({
        status: "In Progress",
        author_id: adminId,
        accepted_at: new Date(),
      })
      .eq("id", id);

    if (error) throw error;

    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Accepted",
        message: `Your writing request (#${id}) is now being worked on.`,
        created_at: new Date(),
      },
    ]);

    res.json({ message: "Order accepted. Admin is now writing." });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ===============================
   ADMIN COMPLETES ORDER
=============================== */
export const completeOrder = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { id } = req.params;
    const { content_text, notes_url } = req.body;

    const { data: order } = await supabase
      .from("writing_orders")
      .select("user_id, author_id")
      .eq("id", id)
      .single();

    if (!order) return res.status(404).json({ error: "Order not found" });
    if (order.author_id !== adminId)
      return res.status(403).json({ error: "Unauthorized" });

    const { error } = await supabase
      .from("writing_orders")
      .update({
        status: "Completed",
        completed_at: new Date(),
        notes_url: notes_url || null,
        final_text: content_text || null,
      })
      .eq("id", id);

    if (error) throw error;

    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Completed",
        message: `Your writing order (#${id}) is now ready. Download or read it.`,
        created_at: new Date(),
      },
    ]);

    res.json({ message: "Order completed and delivered to user." });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ===============================
   ADMIN REJECTS ORDER
=============================== */
export const rejectOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const { data: order } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", id)
      .single();

    if (!order) return res.status(404).json({ error: "Order not found" });

    await supabase
      .from("writing_orders")
      .update({
        status: "Rejected",
        rejection_reason: reason || "Not specified",
        rejected_at: new Date(),
      })
      .eq("id", id);

    await supabase.from("user_notifications").insert([
      {
        user_id: order.user_id,
        title: "Order Rejected",
        message: `Your writing order #${id} was rejected. Reason: ${reason}`,
        created_at: new Date(),
      },
    ]);

    res.json({ message: "Order rejected and user notified." });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ===============================
   ADMIN FILE UPLOAD CONTROLLER
=============================== */
export const uploadWritingFile = async (req, res) => {
  try {
    const file = req.file;
    if (!file) return res.status(400).json({ error: "No file provided" });

    const fileName = `${Date.now()}-${file.originalname}`;

    const { error: uploadError } = await supabase.storage
      .from("writing_uploads")
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (uploadError) {
      console.error("Supabase upload error:", uploadError.message);
      return res.status(500).json({ error: "Supabase upload failed" });
    }

    const { data: publicUrl } = supabase.storage
      .from("writing_uploads")
      .getPublicUrl(fileName);

    res.json({
      message: "File uploaded successfully",
      url: publicUrl.publicUrl,
    });
  } catch (err) {
    console.error("Upload controller error:", err.message);
    res.status(500).json({ error: "Internal server error" });
  }
};

/* ===============================
   ADMIN REPLY ON ORDER
=============================== */
export const adminReply = async (req, res) => {
  try {
    const adminId = req.user.id;
    const adminName = req.user.user_metadata?.full_name || req.user.email;
    const { order_id, message } = req.body;

    if (!order_id || !message) {
      return res
        .status(400)
        .json({ error: "order_id and message are required" });
    }

    const { data: feedbackData, error: feedbackError } = await supabase
      .from("writing_feedback")
      .insert([
        {
          order_id,
          user_id: adminId,
          user_name: adminName,
          message,
          sender: "admin",
          created_at: new Date(),
        },
      ])
      .select();

    if (feedbackError) throw feedbackError;

    const { data: orderData, error: orderErr } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", order_id)
      .single();

    if (orderErr) throw orderErr;

    const { error: notifError } = await supabase
      .from("user_notifications")
      .insert([
        {
          user_id: orderData.user_id,
          title: "New Message From Admin",
          message: `Admin replied to your writing order #${order_id}: "${message}"`,
          created_at: new Date(),
        },
      ]);

    if (notifError) throw notifError;

    res.json({
      message: "Reply sent & user notified",
      feedback: feedbackData[0],
    });
  } catch (err) {
    console.error("adminReply error:", err);
    res.status(500).json({ error: "Reply failed" });
  }
};
