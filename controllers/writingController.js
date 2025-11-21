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
   PLACE NEW ORDER (with optional attachments_url)
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
      instructions,        // ✅ ADD THIS
      citation_style,      // ✅ ADD THIS
      attachments_url      // OPTIONAL
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
          deadline,
          instructions,       // ✅ SAVE IT
          citation_style,     // ✅ SAVE IT
          attachments_url: attachments_url || null,
          total_price,
          status: "Pending",
        },
      ])
      .select()
      .single();

    if (error) throw error;

    res.json({
      message: "Order placed successfully!",
      order: data,
    });

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
    .in("status", ["Pending", "In Progress"]);

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
   GET ORDER BY ID (user can view final_text + notes_url)
===================================================== */
export const getOrderById = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const { data, error } = await supabase
      .from("writing_orders")
      .select("*, final_text, notes_url")  
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
   UPDATE ORDER (deadline + additional notes)
===================================================== */
export const updateOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const updatedBy = req.user.user_metadata?.full_name || req.user.email;

    const { id } = req.params;
    const { deadline, additional_notes } = req.body;

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, author_id, status")
      .eq("id", id)
      .single();

    if (error || !order)
      return res.status(404).json({ error: "Order not found" });

    if (order.user_id !== userId)
      return res.status(403).json({ error: "Unauthorized" });

    if (order.status !== "Pending")
      return res.status(400).json({ error: "Only pending orders can be edited" });

    await supabase
      .from("writing_orders")
      .update({
        deadline,
        additional_notes,
        updated_by: updatedBy,
        updated_at: new Date(),
      })
      .eq("id", id);

    // Notify writer if one exists
    if (order.author_id) {
      await supabase.from("user_notifications").insert([
        {
          user_id: order.author_id,
          title: "Order Updated",
          message: `Order #${id} updated by ${updatedBy}.`,
          created_at: new Date(),
        },
      ]);
    }

    res.json({ message: "Order updated & writer notified" });

  } catch (err) {
    res.status(500).json({ error: "Server error updating order" });
  }
};

/* =====================================================
   SEND MESSAGE / FEEDBACK TO WRITER
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
      writer_name: writer_name || "Writer",
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
/* ===============================
   USER FILE UPLOAD (attachments)
=============================== */

import multer from "multer";
const upload = multer({ storage: multer.memoryStorage() }).single("file");

export const uploadUserAttachment = (req, res) => {
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
      const fileName = `user-${req.user.id}-${Date.now()}-${file.originalname.replace(/\s+/g, "_")}`;

      // Upload to Supabase Storage
      const { error: uploadError } = await supabase.storage
        .from("writing_uploads")
        .upload(fileName, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadError) {
        console.error("Supabase upload error:", uploadError);
        return res.status(500).json({ error: "Supabase upload failed", details: uploadError.message });
      }

      // Get Public URL
      const { data: publicUrl } = supabase.storage
        .from("writing_uploads")
        .getPublicUrl(fileName);

      return res.json({
        message: "File uploaded successfully",
        url: publicUrl.publicUrl
      });
    } catch (error) {
      console.error("uploadUserAttachment error:", error);
      return res.status(500).json({ error: "Internal Server Error", details: error.message });
    }
  });
};

