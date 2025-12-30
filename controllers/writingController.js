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
    const userId = req.user.id; // ✅ UUID
    const updatedByName =
      req.user.user_metadata?.full_name || req.user.email;

    const { id } = req.params;
    const { deadline, additional_notes } = req.body;

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, author_id, status")
      .eq("id", id)
      .single();

    if (error || !order) {
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
  user_updated_at: new Date().toISOString(),
  user_updated_notes: additional_notes || null,
})

      .eq("id", id);

    if (updateErr) {
      console.error(updateErr);
      return res.status(500).json({ error: "Failed to update order" });
    }

    // Notify writer
    if (order.author_id) {
      await supabase.from("user_notifications").insert([
        {
          user_id: order.author_id,
          title: "Order Updated",
          message: `Order #${id} updated by ${updatedByName}.`,
        },
      ]);
    }

    return res.json({ message: "Order updated & writer notified" });
  } catch (err) {
    console.error(err);
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
export const createWritingOrder = async (req, res) => {
  try {
    const body = req.body;

    // FIX: stop requiring payment_success from frontend
    if (!body.total_price) {
      return res.status(400).json({ error: "Invalid order payload" });
    }

    const insertPayload = {
      user_id: req.user.id,
      user_name: req.user.user_metadata?.full_name || req.user.email,

      title: body.title,
      type: body.type,
      academic_level: body.academic_level,
      subject_area: body.subject_area,
      pages: Number(body.pages),
      instructions: body.instructions,
      attachments_url: body.attachments_url,

      total_price: Number(body.total_price),

      // ALWAYS set as paid (because payment already verified)
      payment_success: true,
      payment_status: "Paid",
      paid_at: new Date().toISOString(),

      status: "Pending",
      created_at: new Date(),
    };

    const { data, error } = await supabase
      .from("writing_orders")
      .insert(insertPayload)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, order: data });
    
  } catch (err) {
    console.error("createWritingOrder error:", err);
    return res.status(500).json({ error: err.message });
  }
};



export const verifyWritingPayment = async (req, res) => {
  try {
    const userId = req.user.id;
    const { amount, method, order_temp_id } = req.body;

    if (!amount || !order_temp_id) {
      return res.status(400).json({ error: "Amount and temp ID required" });
    }

    // Insert into transactions
    const { data: txData, error: txErr } = await supabase
      .from("payments_transactions")
      .insert([
        {
          user_id: userId,
          amount,
          status: "completed",
          method: method || "test-payment",
          description: `writing_service:${order_temp_id}`,
          external_ref: order_temp_id,
          created_at: new Date(),
        },
      ])
      .select()
      .single();

    if (txErr) throw txErr;

    // Insert revenue
    const { error: revenueErr } = await supabase
      .from("revenue") // make sure table exists
      .insert([
        {
          user_id: userId,
          amount,
          item_type: "writing_service",
          created_at: new Date(),
        },
      ]);

    if (revenueErr) throw revenueErr;

    return res.json({ success: true, transaction: txData });

  } catch (err) {
    console.error("verifyWritingPayment ERROR:", err);
    return res.status(500).json({ error: "Payment verification failed" });
  }
};




/* =====================================================
   GET ALL INTERVIEW MATERIALS
===================================================== */
export const getInterviewMaterials = async (req, res) => {
  try {
    const { category, search } = req.query;

    let query = supabase
      .from("interview_materials")
      .select("id, title, category, file_url")
      .eq("is_active", true);

    if (category && category !== "All") {
      query = query.eq("category", category);
    }

    if (search) {
      query = query.ilike("title", `%${search}%`);
    }

    const { data, error } = await query.order("created_at", {
      ascending: false,
    });

    if (error) {
      console.error("getInterviewMaterials error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.json(data || []);
  } catch (err) {
    console.error("getInterviewMaterials server error:", err);
    return res.status(500).json({ error: "Failed to load materials" });
  }
};

/* =====================================================
   GET SINGLE MATERIAL
===================================================== */
export const getInterviewMaterialById = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from("interview_materials")
      .select("*")
      .eq("id", id)
      .eq("is_active", true)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: "Material not found" });
    }

    return res.json(data);
  } catch (err) {
    console.error("getInterviewMaterialById error:", err);
    return res.status(500).json({ error: "Failed to load material" });
  }
};

/* =====================================================
   STREAM INTERVIEW MATERIAL PDF (FOR PDFJS)
===================================================== */
// controllers/writingController.js
import { supabaseAdmin } from "../utils/supabaseClient.js";

// controllers/writingController.js

export const streamInterviewMaterialPdf = async (req, res) => {
  try {
    const { id } = req.params;

    // 1️⃣ fetch interview material entry
    const { data, error } = await supabaseAdmin
      .from("interview_materials")
      .select("file_url")
      .eq("id", id)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: "Interview material not found" });
    }

    // file_url is like: admin-1767083451486-E-Book Report.pdf
    const objectPath = data.file_url;

    // 2️⃣ generate public URL from the bucket
    const { data: publicFile } = await supabaseAdmin.storage
      .from("interview_materials")
      .getPublicUrl(objectPath);

    if (!publicFile?.publicUrl) {
      return res.status(500).json({ error: "Failed to generate file URL" });
    }

    // 3️⃣ return usable URL
    return res.json({
      url: publicFile.publicUrl,  // <-- FIXED usable URL
      type: "public",
    });

  } catch (err) {
    console.error("streamInterviewMaterialPdf error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
};



export const downloadOrderFile = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const { data: order, error } = await supabaseAdmin
      .from("writing_orders")
      .select("notes_url, user_id")
      .eq("id", id)
      .single();

    if (error || !order) {
      return res.status(404).json({ error: "Order not found" });
    }

    if (order.user_id !== userId) {
      return res.status(403).json({ error: "Unauthorized" });
    }

    if (!order.notes_url) {
      return res.status(400).json({ error: "No file available" });
    }

    // ---------------------------
    // 🔥 EXTRACT only the object key
    // ---------------------------
    const fullUrl = order.notes_url;

    // find marker `/writing_uploads/`
    const marker = "/writing_uploads/";
    const idx = fullUrl.indexOf(marker);

    if (idx === -1) {
      return res.status(500).json({ error: "Invalid stored notes_url format" });
    }

    const key = decodeURIComponent(fullUrl.substring(idx + marker.length));

    console.log("🗝 Object Key =", key);

    // ---------------------------
    // Get public URL again (works even if already public)
    // ---------------------------
    const { data: publicData } = supabaseAdmin.storage
      .from("writing_uploads")
      .getPublicUrl(key);

    return res.json({ url: publicData.publicUrl });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Server error" });
  }
};
