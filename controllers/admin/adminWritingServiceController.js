import supabase from "../../utils/pgClient.js";
import fs from "fs";
import path from "path";

/* ============================================================
   ADMIN: GET ALL PAID WRITING ORDERS
=============================================================== */
export const getAllOrders = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
      .eq("payment_success", true) // ONLY PAID ORDERS
      .order("created_at", { ascending: false });

    if (error) throw error;

    return res.json(data);
  } catch (err) {
    console.error("getAllOrders Error:", err);
    return res.status(500).json({ error: "Failed to load orders" });
  }
};

/* ============================================================
   ADMIN: GET ONLY PENDING PAID ORDERS
=============================================================== */
export const getPendingOrders = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("writing_orders")
      .select("*")
    .eq("payment_success", true)
    .eq("status", "Pending")

      .order("created_at", { ascending: false });

    if (error) throw error;

    return res.json(data);
  } catch (err) {
    console.error("getPendingOrders Error:", err);
    return res.status(500).json({ error: "Failed to load pending orders" });
  }
};

/* ============================================================
   ADMIN: ACCEPT ORDER
=============================================================== */
export const acceptOrder = async (req, res) => {
  try {
    const id = req.params.id;
    const adminId = req.user.id;

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, status, payment_success")
      .eq("id", id)
      .single();

    if (error || !order) {
      return res.status(404).json({ error: "Order not found" });
    }

    if (!order.payment_success) {
      return res.status(403).json({ error: "Unpaid order" });
    }

    if (order.status !== "Pending") {
      return res.status(400).json({ error: "Order already processed" });
    }

    const { error: updateErr } = await supabase
      .from("writing_orders")
      .update({
        status: "In Progress",
         progress: 30,
        author_id: adminId,
        accepted_at: new Date().toISOString(),
        admin_updated_at: new Date().toISOString(),
        admin_updated_by: adminId,
      })
      .eq("id", id)
      .eq("status", "Pending"); // race-safe

    if (updateErr) throw updateErr;

    await supabase.from("user_notifications").insert({
      user_id: order.user_id,
      title: "Order Accepted",
      message: `Your writing request (#${id}) is now in progress.`,
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("acceptOrder Error:", err);
    return res.status(500).json({ error: "Failed to accept order" });
  }
};


/* ============================================================
   ADMIN: COMPLETE ORDER
=============================================================== */
export const completeOrder = async (req, res) => {
  try {
    const id = req.params.id;
    let { final_text, notes_url } = req.body;

    if (!final_text && !notes_url) {
      return res.status(400).json({ error: "Final text or file required" });
    }

    // 🟢 If admin uploaded PDF, make it the primary deliverable
    if (notes_url) {
      final_text = null;  // <-- IMPORTANT FIX
    }

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, status")
      .eq("id", id)
      .single();

    if (error || !order) {
      return res.status(404).json({ error: "Order not found" });
    }

    if (order.status !== "In Progress") {
      return res.status(400).json({ error: "Order not in progress" });
    }

    const { error: updateErr } = await supabase
      .from("writing_orders")
      .update({
        status: "Completed",
        progress: 100,
        final_text,      // <-- only saved if PDF isn't provided
        notes_url,       // <-- PDF deliverable
        completed_at: new Date().toISOString(),
        admin_updated_at: new Date().toISOString(),
        admin_updated_by: req.user.id,
      })
      .eq("id", id)
      .eq("status", "In Progress");

    if (updateErr) throw updateErr;

    await supabase.from("user_notifications").insert({
      user_id: order.user_id,
      title: "Order Completed",
      message: `Your writing order (#${id}) is now ready.`,
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("completeOrder Error:", err);
    return res.status(500).json({ error: "Failed to complete order" });
  }
};



/* ============================================================
   ADMIN: REJECT ORDER
=============================================================== */
export const rejectOrder = async (req, res) => {
  try {
    const id = req.params.id;
    const { reason } = req.body;

    if (!reason) {
      return res.status(400).json({ error: "Rejection reason required" });
    }

    const { data: order, error } = await supabase
      .from("writing_orders")
      .select("id, user_id, status")
      .eq("id", id)
      .single();

    if (error || !order) {
      return res.status(404).json({ error: "Order not found" });
    }

    if (order.status !== "Pending") {
      return res.status(400).json({ error: "Only pending orders can be rejected" });
    }

    const { error: updateErr } = await supabase
      .from("writing_orders")
      .update({
        status: "Rejected",
        rejection_reason: reason,
        rejected_at: new Date().toISOString(),
        admin_updated_at: new Date().toISOString(),
        admin_updated_by: req.user.id,
      })
      .eq("id", id)
      .eq("status", "Pending");

    if (updateErr) throw updateErr;

    await supabase.from("user_notifications").insert({
      user_id: order.user_id,
      title: "Order Rejected",
      message: `Your writing order (#${id}) was rejected. Reason: ${reason}`,
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("rejectOrder Error:", err);
    return res.status(500).json({ error: "Failed to reject order" });
  }
};


/* ============================================================
   ADMIN: SEND MESSAGE TO USER
=============================================================== */
export const adminReply = async (req, res) => {
  try {
    const { order_id, message } = req.body;

    if (!order_id || !message)
      return res.status(400).json({ error: "Missing fields" });

    const adminName = req.user.user_metadata?.full_name || "Admin";

    const { data: order, error: findErr } = await supabase
      .from("writing_orders")
      .select("user_id")
      .eq("id", order_id)
      .single();

    if (findErr) throw findErr;

    // Store chat message
    await supabase.from("writing_feedback").insert({
      order_id,
      user_id: order.user_id,
      writer_name: adminName,
      message,
      sender: "admin",
      created_at: new Date(),
    });

    await supabase
  .from("writing_orders")
  .update({
    progress: 60,
    admin_updated_at: new Date().toISOString(),
    admin_updated_by: req.user.id,
  })
  .eq("id", order_id)
  .lt("progress", 60); // prevents downgrade


    // Notify user
    await supabase.from("user_notifications").insert({
      user_id: order.user_id,
      title: "New Message From Admin",
      message: `Admin replied to your writing order #${order_id}: "${message}"`,
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("adminReply Error:", err);
    return res.status(500).json({ error: "Failed to send reply" });
  }
};

/* ============================================================
   ADMIN: MARK MESSAGE AS READ
=============================================================== */
export const markAsRead = async (req, res) => {
  try {
    const orderId = req.params.order_id;

    const { error } = await supabase
      .from("writing_feedback")
      .update({ read_by_admin: true })
      .eq("order_id", orderId);

    if (error) throw error;

    return res.json({ success: true });
  } catch (err) {
    console.error("markAsRead Error:", err);
    return res.status(500).json({ error: "Failed to mark messages" });
  }
};

/* ============================================================
   ADMIN: UPLOAD FINAL NOTES / FILE
=============================================================== */
export const uploadWritingFile = async (req, res) => {
  try {
    if (!req.file)
      return res.status(400).json({ error: "File not provided" });

    const file = req.file;
    const filename = `admin-${Date.now()}-${file.originalname.replace(/\s+/g, "_")}`;
    const uploadDir = path.join(process.cwd(), "uploads", "writing_uploads");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, file.buffer);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/writing_uploads/${filename}`;

    return res.json({ url: publicUrl });
  } catch (err) {
    console.error("uploadWritingFile Error:", err);
    return res.status(500).json({ error: "File upload failed" });
  }
};


/* ============================================================
   ADMIN: CREATE INTERVIEW MATERIAL (PDF ONLY)
=============================================================== */
export const createInterviewMaterial = async (req, res) => {
  try {
    const { title, category, description } = req.body;
    const file = req.file;

    if (!title || !category || !file) {
      return res.status(400).json({ error: "Missing fields" });
    }

    // Allow only PDFs
    if (file.mimetype !== "application/pdf") {
      return res.status(400).json({ error: "Only PDF allowed" });
    }

    const filename = `interview-${Date.now()}-${file.originalname.replace(/\s+/g, "_")}`;
    const uploadDir = path.join(process.cwd(), "uploads", "interview_materials");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, file.buffer);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/interview_materials/${filename}`;

    const { error: insertError } = await supabase
      .from("interview_materials")
      .insert({
        title,
        category,
        description,
        file_url: publicUrl,
        is_active: true,
      });

    if (insertError) throw insertError;

    return res.json({ success: true });
  } catch (err) {
    console.error("createInterviewMaterial error:", err);
    return res.status(500).json({ error: "Failed to create material" });
  }
};


/* ============================================================
   ADMIN: GET ALL INTERVIEW MATERIALS
=============================================================== */
export const getInterviewMaterials = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("interview_materials")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) throw error;

    return res.json(data);
  } catch (err) {
    console.error("getInterviewMaterials Error:", err);
    return res.status(500).json({ error: "Failed to load materials" });
  }
};


/* ============================================================
   ADMIN: DELETE INTERVIEW MATERIAL
=============================================================== */
export const deleteInterviewMaterial = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from("interview_materials")
      .delete()
      .eq("id", id);

    if (error) throw error;

    return res.json({ success: true });
  } catch (err) {
    console.error("deleteInterviewMaterial Error:", err);
    return res.status(500).json({ error: "Failed to delete material" });
  }
};

/* ============================================================
   ADMIN: UPLOAD INTERVIEW MATERIAL FILE
=============================================================== */
