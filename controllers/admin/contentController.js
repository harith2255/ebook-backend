// controllers/admin/contentController.js
import { supabaseAdmin as supabase } from "../../utils/supabaseClient.js";
 // default admin client (service role)
import getPdfPageCount from "../../utils/pdfReader.js"; // your latin1-based page counter
// If you're using multer for file uploads, req.file.buffer is expected

/**
 * uploadContent
 * Accepts multipart/form-data
 * Required fields in body: type ("E-Book" | "Notes" | "Mock Test"), title, author
 * Optional: category, description, price, scheduled_date, difficulty, total_questions, duration_minutes
 */
export const uploadContent = async (req, res) => {
  try {
    const { type } = req.body;
    const title = req.body.title || "";
    const author = req.body.author || "";
    const category = req.body.category || "";
    const description = req.body.description || "";
    const price = req.body.price ? Number(req.body.price) : null;

    const file = req.files?.file?.[0] || null;
    const cover = req.files?.cover?.[0] || null;


    // --- Parse MCQs safely (for mock tests) ---
let mcqs = [];
try {
  if (req.body.mcqs) {
    mcqs = JSON.parse(req.body.mcqs);
  }
} catch (e) {
  console.error("❌ Failed to parse MCQs:", e);
  mcqs = [];
}


    // ✅ FIXED VALIDATION
    if (!type || !title) {
      return res.status(400).json({ error: "type and title are required" });
    }

    if (type !== "Mock Test" && !author) {
      return res.status(400).json({ error: "author is required for E-Book and Notes" });
    }

    const table =
      type === "E-Book" ? "ebooks" :
      type === "Notes" ? "notes" :
      type === "Mock Test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid content type" });

    let publicUrl = null;
    let coverUrl = null;
    let pageCount = 0;

    // --- FILE UPLOAD ---
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;

      const { error: uploadErr } = await supabase.storage
        .from(table)
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadErr) {
        console.error("Storage upload error:", uploadErr);
        return res.status(400).json({ error: uploadErr.message });
      }

      const { data: publicData } = supabase.storage
        .from(table)
        .getPublicUrl(filePath);

      publicUrl = publicData?.publicUrl ?? null;

      if (file.mimetype === "application/pdf") {
        try {
          pageCount = getPdfPageCount(file.buffer) || 0;
        } catch (err) {
          console.warn("pdf page count failed:", err);
        }
      }
    }

    // --- COVER IMAGE UPLOAD ---
    if (cover) {
      const coverPath = `${Date.now()}-${cover.originalname}`;

      const { error: coverErr } = await supabase.storage
        .from("covers")
        .upload(coverPath, cover.buffer, {
          contentType: cover.mimetype,
          upsert: false,
        });

      if (coverErr) {
        console.error("Cover upload error:", coverErr);
        return res.status(400).json({ error: coverErr.message });
      }

      const { data: coverData } = supabase.storage
        .from("covers")
        .getPublicUrl(coverPath);

      coverUrl = coverData?.publicUrl || null;
    }

    // --- BUILD INSERT OBJECT ---
    let insertObj = null;

    if (table === "ebooks") {
      insertObj = {
        title,
        author,
        category: category || null,
        description: description || null,
        pages: pageCount || 0,
        price: price !== null ? price : null,
        sales: 0,
        status: "Published",
        file_url: publicUrl,
        cover_url: coverUrl,
        created_at: new Date().toISOString(),
        tags: [],
        summary: "",
        embedding: null,
      };
    }

    if (table === "notes") {
      insertObj = {
        title,
        category: category || null,
        author,
        pages: pageCount || 0,
        downloads: 0,
        rating: 0,
        price: price !== null ? price : 0,
        featured: false,
        file_url: publicUrl,
        cover_url: coverUrl,
        preview_content: "",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        description: description || null,
        tags: [],
        summary: "",
        embedding: null,
      };
    }



    if (table === "mock_tests") {
      insertObj = {
        title,
        scheduled_date: req.body.scheduled_date
          ? new Date(req.body.scheduled_date).toISOString()
          : new Date().toISOString(),
        total_questions: Number(req.body.total_questions || 0),
        duration_minutes: Number(req.body.duration_minutes || 0),
        created_at: new Date().toISOString(),
        subject: req.body.subject || category || "General",
        difficulty: req.body.difficulty || "Medium",
        participants: 0,
         mcqs,
      };
    }

    const { data, error } = await supabase
      .from(table)
      .insert([insertObj])
      .select()
      .single();

    if (error) {
      console.error("Insert error:", error);
      return res.status(400).json({ error: error.message });
    }

    return res.status(201).json({ message: "Content uploaded", data });

  } catch (err) {
    console.error("uploadContent error:", err);
    return res.status(500).json({ error: "Server error uploading content" });
  }
};


/**
 * listContent
 * query params:
 *  - type: "books" | "notes" | "tests"
 *  - search: optional search string
 */
export const listContent = async (req, res) => {
  try {
    const { type } = req.query;

    const table =
      type === "books" ? "ebooks" :
      type === "notes" ? "notes" :
      type === "tests" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    // For mock tests → include attempts count
    if (table === "mock_tests") {
      const { data, error } = await supabase
        .from("mock_tests")
        .select("*, attempts:mock_attempts(count)")
        .order("created_at", { ascending: false });

      if (error) return res.status(400).json({ error: error.message });

      return res.json({ contents: data });
    }

    // For books and notes → normal fetch
    const { data, error } = await supabase
      .from(table)
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ contents: data });

  } catch (err) {
    console.error("List error:", err);
    return res.status(500).json({ error: "Server error" });
  }
};

/**
 * deleteContent
 * DELETE /api/admin/content/:type/:id
 * type param: "book" | "note" | "test"
 */
export const deleteContent = async (req, res) => {
  try {
    const { type, id } = req.params;

    console.log("🔥 Backend DELETE HIT:", { type, id });

    const table =
      type === "book" || type === "ebook" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    console.log("📌 Resolved table:", table);

    if (!table) {
      console.log("❌ Invalid type received:", type);
      return res.status(400).json({ error: "Invalid type" });
    }

    // Prevent deleting mock_tests with existing attempts
    if (table === "mock_tests") {
      console.log("🔍 Checking attempts for mock test:", id);

      const { data: attempts, error: attemptErr } = await supabase
        .from("mock_attempts")
        .select("id")
        .eq("test_id", id)
        .limit(1);

      console.log("📌 Attempts Query Result:", { attempts, attemptErr });

      if (attemptErr) {
        console.error("❌ Check attempts error:", attemptErr);
        return res.status(400).json({ error: "Failed to check attempts" });
      }

      if (attempts && attempts.length > 0) {
        console.log("⛔ Cannot delete mock test; attempts exist");
        return res.status(400).json({
          error: "Cannot delete this mock test because users have attempted it.",
        });
      }
    }

    console.log("🗑️ Attempting DELETE:", { table, id });

    // Perform delete with count for debugging
    const { data, error, count } = await supabase
      .from(table)
      .delete({ count: "exact" })
      .eq("id", id);

    console.log("🧪 Supabase DELETE Result:", { data, error, count });

    if (error) {
      console.error("❌ Supabase delete error:", error);
      return res.status(400).json({ error: error.message || "Delete failed" });
    }

    if (count === 0) {
      console.warn("⚠️ No rows deleted. Possible RLS block or wrong ID:", id);
    }

    return res.json({ message: "Content deleted", deleted: count });

  } catch (err) {
    console.error("🔥 deleteContent error (server crash):", err);
    return res.status(500).json({ error: "Server error deleting content" });
  }
};



/**
 * editContent
 * PUT /api/admin/content/:type/:id
 * Accepts multipart/form-data to optionally replace file
 * Only updates columns that exist for the table.
 */
export const editContent = async (req, res) => {
  try {
    const { type, id } = req.params;
    const updates = { ...req.body };

    const file = req.files?.file?.[0] || null;     // main file
    const cover = req.files?.cover?.[0] || null;   // NEW cover file

    const table =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    let file_url = null;
    let cover_url = null;

    // Replace main file
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;
      const { error } = await supabase.storage
        .from(table)
        .upload(filePath, file.buffer, { contentType: file.mimetype });

      if (error) return res.status(400).json({ error: error.message });

      const { data: urlData } = supabase.storage.from(table).getPublicUrl(filePath);
      file_url = urlData?.publicUrl;
      updates.file_url = file_url;
    }

    // Replace cover image (NEW)
    if (cover) {
      const coverPath = `${Date.now()}-${cover.originalname}`;
      const { error } = await supabase.storage
        .from("covers")
        .upload(coverPath, cover.buffer, { contentType: cover.mimetype });

      if (error) return res.status(400).json({ error: error.message });

      const { data: urlData } = supabase.storage
        .from("covers")
        .getPublicUrl(coverPath);

      cover_url = urlData?.publicUrl;
      updates.cover_url = cover_url;
    }

    const { data, error } = await supabase
      .from(table)
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ message: "Content updated", data });

  } catch (err) {
    console.error("editContent error:", err);
    return res.status(500).json({ error: "Server error editing content" });
  }
};

export default {
  uploadContent,
  listContent,
  deleteContent,
  editContent,
};