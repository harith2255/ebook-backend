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

    // Confirm order exists
    const { data: order } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", id)
      .single();

    if (!order) return res.status(404).json({ error: "Order not found" });

    // Update order status
    const { error } = await supabase
      .from("writing_orders")
      .update({
        status: "In Progress",
        author_id: adminId, // admin becomes writer
        accepted_at: new Date(),
      })
      .eq("id", id);

    if (error) throw error;

    // Notify User
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
    const { content_text, notes_url } = req.body; // admin can upload file OR type text

    // Fetch order
    const { data: order } = await supabase
      .from("writing_orders")
      .select("user_id, author_id")
      .eq("id", id)
      .single();

    if (!order) return res.status(404).json({ error: "Order not found" });
    if (order.author_id !== adminId)
      return res.status(403).json({ error: "Unauthorized" });

    // Complete order
    const { error } = await supabase
      .from("writing_orders")
      .update({
        status: "Completed",
        completed_at: new Date(),
        notes_url: notes_url || null,
        final_text: content_text || null, // admin-written text
      })
      .eq("id", id);

    if (error) throw error;

    // Notify User
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

    // Reject order
    await supabase
      .from("writing_orders")
      .update({
        status: "Rejected",
        rejection_reason: reason || "Not specified",
        rejected_at: new Date(),
      })
      .eq("id", id);

    // Notify user
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
import multer from "multer";
const upload = multer({ storage: multer.memoryStorage() }).single("file");

export const uploadWritingFile = async (req, res) => {
  upload(req, res, async (err) => {
    try {
      if (err) {
        console.error("Multer error:", err);
        return res.status(400).json({ error: "File upload failed" });
      }

      if (!req.file) {
        return res.status(400).json({ error: "No file provided" });
      }

      const file = req.file;
      const fileName = `${Date.now()}-${file.originalname}`;

      // Upload to Supabase Storage
      const { error: uploadError } = await supabase.storage
        .from("writing_uploads") // make sure this bucket exists
        .upload(fileName, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadError) {
        console.error("Supabase upload error:", uploadError.message);
        return res.status(500).json({ error: "Supabase upload failed" });
      }

      // Generate public URL
      const { data: publicUrl } = supabase.storage
        .from("writing_uploads")
        .getPublicUrl(fileName);

      res.json({
        message: "File uploaded successfully",
        url: publicUrl.publicUrl,
      });
    } catch (error) {
      console.error("Upload controller error:", error.message);
      res.status(500).json({ error: "Internal server error" });
    }
  });
};

export const adminReply = async (req, res) => {
  try {
    const adminId = req.user.id;
    const adminName = req.user.user_metadata?.full_name || req.user.email;

    const { order_id, message } = req.body;

    if (!order_id || !message) {
      return res.status(400).json({ error: "order_id and message are required" });
    }

    // Insert feedback message
    const { error: feedbackError, data: feedbackData } = await supabase
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

    // Get order user id (to notify them)
    const { data: orderData, error: orderErr } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", order_id)
      .single();

    if (orderErr) throw orderErr;

    const userId = orderData.user_id;

    // Insert user notification
    const { error: notifError } = await supabase
      .from("user_notifications")
      .insert([
        {
          user_id: userId,
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
