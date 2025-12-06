// controllers/writingServiceController.js
import supabase from "../utils/supabaseClient.js";
import multer from "multer";

/* =====================================================
   GET ALL WRITING SERVICES
===================================================== */
export const getServices = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("writing_services")
      .select("*")
      .order("id", { ascending: true });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
  } catch (err) {
    console.error("getServices error:", err);
    return res.status(500).json({ error: "Failed to load services" });
  }
};

/* =====================================================
   PLACE NEW ORDER (DEV: call ONLY AFTER payment confirm)
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
      instructions,
      attachments_url,
    } = req.body;

    // Basic validation
    if (!title || !type) {
      return res.status(400).json({ error: "Title and type are required" });
    }

    const pagesNum = Number(pages) || 0;
    const priceNum = Number(total_price) || 0;

    const insertPayload = {
      user_id: userId,
      user_name: userName,

      title,
      type,
      subject_area: subject_area || null,
      academic_level: academic_level || null,

      pages: pagesNum,
      deadline: deadline || null,

      instructions: instructions || null,
      attachments_url: attachments_url || null,
      total_price: priceNum,

      // DEV MODE ASSUMPTION:
      // This controller is called AFTER payment is "confirmed" in your fake flow.
      // So: order is paid, but still "Pending" so admin can Accept it.
      status: "Pending",
      paid_at: new Date().toISOString(),

      created_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from("writing_orders")
      .insert([insertPayload])
      .select()
      .single();

    if (error) {
      console.error("Supabase insert error (placeOrder):", error);
      return res.status(500).json({ error: error.message });
    }

    // Optional: notify user
    const notif = await supabase.from("user_notifications").insert([
      {
        user_id: userId,
        title: "Writing Order Submitted",
        message: `Your writing order "${title}" has been submitted successfully.`,
        created_at: new Date(),
      },
    ]);

    if (notif.error) {
      console.warn("user_notifications insert error:", notif.error.message);
    }

    return res.json({
      message: "Order created successfully",
      order: data,
    });
  } catch (err) {
    console.error("placeOrder error:", err);
    return res.status(500).json({ error: "Failed to place order" });
  }
};

/* =====================================================
   GET ACTIVE ORDERS (Pending + In Progress)
===================================================== */
export const getActiveOrders = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("user_id", userId)
      .in("status", ["Pending", "In Progress"])
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
  } catch (err) {
    console.error("getActiveOrders error:", err);
    return res.status(500).json({ error: "Failed to load active orders" });
  }
};

/* =====================================================
   GET COMPLETED ORDERS
===================================================== */
export const getCompletedOrders = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("user_id", userId)
      .eq("status", "Completed")
      .order("completed_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
  } catch (err) {
    console.error("getCompletedOrders error:", err);
    return res.status(500).json({ error: "Failed to load completed orders" });
  }
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

    if (error) {
      console.error("getOrderById error:", error);
      return res.status(404).json({ error: "Order not found" });
    }

    return res.json(data);
  } catch (err) {
    console.error("getOrderById server error:", err);
    return res.status(500).json({ error: "Failed to load order" });
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

    if (error || !order) {
      console.error("updateOrder: order fetch error:", error);
      return res.status(404).json({ error: "Order not found" });
    }

    if (order.user_id !== userId) {
      return res.status(403).json({ error: "Unauthorized" });
    }

    if (order.status !== "Pending") {
      return res
        .status(400)
        .json({ error: "Only pending orders can be edited" });
    }

    const { error: updateErr } = await supabase
      .from("writing_orders")
      .update({
        deadline: deadline || null,
        additional_notes: additional_notes || null,
        updated_by: updatedBy,
        updated_at: new Date().toISOString(),
      })
      .eq("id", id);

    if (updateErr) {
      console.error("updateOrder update error:", updateErr);
      return res.status(500).json({ error: "Failed to update order" });
    }

    // Notify writer if one exists
    if (order.author_id) {
      const { error: notifErr } = await supabase
        .from("user_notifications")
        .insert([
          {
            user_id: order.author_id,
            title: "Order Updated",
            message: `Order #${id} updated by ${updatedBy}.`,
            created_at: new Date(),
          },
        ]);

      if (notifErr) {
        console.warn("updateOrder notification error:", notifErr.message);
      }
    }

    return res.json({ message: "Order updated & writer notified" });
  } catch (err) {
    console.error("updateOrder server error:", err);
    return res.status(500).json({ error: "Server error updating order" });
  }
};

/* =====================================================
   SEND MESSAGE / FEEDBACK TO WRITER
===================================================== */
export const sendFeedback = async (req, res) => {
  try {
    const userId = req.user.id;
    const userName = req.user.user_metadata?.full_name || req.user.email;

    const { order_id, writer_name, message } = req.body;

    if (!order_id || !message) {
      return res
        .status(400)
        .json({ error: "order_id and message are required" });
    }

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

    if (error) {
      console.error("sendFeedback insert error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.json({ message: "Feedback sent successfully" });
  } catch (err) {
    console.error("sendFeedback server error:", err);
    return res.status(500).json({ error: "Failed to send feedback" });
  }
};

/* =====================================================
   GET FEEDBACK FOR ORDER
===================================================== */
export const getFeedbackForOrder = async (req, res) => {
  try {
    const { order_id } = req.params;

    const { data, error } = await supabase
      .from("writing_feedback")
      .select("id, message, writer_name, user_name, created_at")
      .eq("order_id", order_id)
      .order("created_at", { ascending: true });

    if (error) return res.status(400).json({ error: error.message });
    return res.json(data);
  } catch (err) {
    console.error("getFeedbackForOrder error:", err);
    return res.status(500).json({ error: "Failed to load feedback" });
  }
};

/* ===============================
   USER FILE UPLOAD (attachments)
=============================== */

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
      const safeName = file.originalname.replace(/\s+/g, "_");
      const fileName = `user-${req.user.id}-${Date.now()}-${safeName}`;

      const { error: uploadError } = await supabase.storage
        .from("writing_uploads")
        .upload(fileName, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadError) {
        console.error("Supabase upload error:", uploadError);
        return res.status(500).json({
          error: "Supabase upload failed",
          details: uploadError.message,
        });
      }

      const { data: publicUrl } = supabase.storage
        .from("writing_uploads")
        .getPublicUrl(fileName);

      return res.json({
        message: "File uploaded successfully",
        url: publicUrl.publicUrl,
      });
    } catch (error) {
      console.error("uploadUserAttachment error:", error);
      return res
        .status(500)
        .json({ error: "Internal Server Error", details: error.message });
    }
  });
};

/* =====================================================
   GET SINGLE WRITING ORDER
===================================================== */
export const getSingleWritingOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("id", id)
      .eq("user_id", userId)
      .single();

    if (error) {
      console.error("getSingleWritingOrder error:", error);
      return res.status(404).json({ error: "Order not found" });
    }

    return res.json(data);
  } catch (err) {
    console.error("getSingleWritingOrder server error:", err);
    return res.status(500).json({ error: "Failed to load order" });
  }
};
