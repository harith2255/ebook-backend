import supabase from "../../utils/supabaseClient.js";
import getPdfPageCount from "../../utils/pdfReader.js";

/* ============================================================================
   UPLOAD CONTENT
   POST /api/admin/content/upload
============================================================================ */
export const uploadContent = async (req, res) => {
  try {
    const { type } = req.body;
    const title = req.body.title || "";
    const author = req.body.author || "";
    const category = req.body.category || null;
    const description = req.body.description || null;
    const price = req.body.price ? Number(req.body.price) : null;

    const file = req.files?.file?.[0] || null;
    const cover = req.files?.cover?.[0] || null;

    // Parse MCQs (if mock test)
    let mcqs = [];
    try {
      if (req.body.mcqs) {
        mcqs = JSON.parse(req.body.mcqs);
      }
    } catch (e) {
      console.error("❌ Failed to parse MCQs:", e);
    }

    if (!type || !title) {
      return res.status(400).json({ error: "type and title are required" });
    }

    if (type !== "Mock Test" && !author) {
      return res.status(400).json({
        error: "author is required for E-Book and Notes"
      });
    }

    const table =
      type === "E-Book" ? "ebooks" :
      type === "Notes" ? "notes" :
      type === "Mock Test" ? "mock_tests" : null;

    if (!table)
      return res.status(400).json({ error: "Invalid content type" });

    let publicUrl = null;
    let coverUrl = null;
    let pageCount = 0;

    /* ==================== FILE UPLOAD ==================== */
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;

      const { error: uploadErr } = await supabase.storage
        .from(table)
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadErr)
        return res.status(400).json({ error: uploadErr.message });

      const { data: publicData } = supabase.storage
        .from(table)
        .getPublicUrl(filePath);

      publicUrl = publicData?.publicUrl || null;

      if (file.mimetype === "application/pdf") {
        try {
          pageCount = getPdfPageCount(file.buffer);
        } catch (e) {
          console.warn("pdf page count failed:", e);
        }
      }
    }

    /* ==================== COVER UPLOAD ==================== */
    if (cover) {
      const coverPath = `${Date.now()}-${cover.originalname}`;

      const { error: coverErr } = await supabase.storage
        .from("covers")
        .upload(coverPath, cover.buffer, {
          contentType: cover.mimetype,
          upsert: false,
        });

      if (coverErr)
        return res.status(400).json({ error: coverErr.message });

      const { data: coverData } = supabase.storage
        .from("covers")
        .getPublicUrl(coverPath);

      coverUrl = coverData?.publicUrl || null;
    }

    /* ==================== INSERT MAIN ROW ==================== */
    let insertObj = {};

    if (table === "ebooks") {
      insertObj = {
        title,
        author,
        category,
        description,
        pages: pageCount,
        price,
        sales: 0,
        status: "Published",
        file_url: publicUrl,
        cover_url: coverUrl,
        created_at: new Date().toISOString(),
      };
    }

    if (table === "notes") {
      insertObj = {
        title,
        category,
        author,
        pages: pageCount,
        downloads: 0,
        rating: 0,
        price: price || 0,
        featured: false,
        file_url: publicUrl,
        cover_url: coverUrl,
        preview_content: "",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        description,
      };
    }

    if (table === "mock_tests") {
      insertObj = {
        title,
        category,
        description,
        price,
        created_at: new Date().toISOString(),
      };
    }

    const { data: insertData, error: insertError } = await supabase
      .from(table)
      .insert(insertObj)
      .select()
      .single();

    if (insertError)
      return res.status(400).json({ error: insertError.message });


    /* ==================== INSERT MCQs ==================== */
    if (table === "mock_tests" && Array.isArray(mcqs) && insertData?.id) {
      const formatted = mcqs
        .filter(q => q.question?.trim())
        .map(q => ({
          test_id: insertData.id,
          question: q.question,
          option_a: q.options?.[0] || null,
          option_b: q.options?.[1] || null,
          option_c: q.options?.[2] || null,
          option_d: q.options?.[3] || null,
          correct_option: q.answer || null,
        }));

      if (formatted.length) {
        const { error: qErr } = await supabase
          .from("mock_test_questions")
          .insert(formatted);

        if (qErr)
          console.error("❌ MCQ insert error:", qErr);
      }
    }

    return res.status(201).json({
      message: "Content uploaded",
      data: insertData,
    });

  } catch (err) {
    console.error("uploadContent error:", err);
    return res.status(500).json({ error: "Server error uploading content" });
  }
};


/* ============================================================================
   LIST CONTENT
   GET /api/admin/content?type=books|notes|tests
============================================================================ */
export const listContent = async (req, res) => {
  try {
    const { type } = req.query;

    let table =
      ["book", "books", "ebook", "ebooks"].includes(type) ? "ebooks" :
      ["note", "notes"].includes(type) ? "notes" :
      ["test", "tests", "mock_test", "mock_tests"].includes(type) ? "mock_tests" :
      null;

    if (!table)
      return res.status(400).json({ error: "Invalid type" });

    if (table === "mock_tests") {
      const { data, error } = await supabase
        .from("mock_tests")
        .select("*, attempts:mock_attempts(count)")
        .order("created_at", { ascending: false });

      if (error)
        return res.status(400).json({ error: error.message });

      return res.json({ contents: data });
    }

    const { data, error } = await supabase
      .from(table)
      .select("*")
      .order("created_at", { ascending: false });

    if (error)
      return res.status(400).json({ error: error.message });

    return res.json({ contents: data });

  } catch (err) {
    console.error("List error:", err);
    return res.status(500).json({ error: "Server error" });
  }
};


/* ============================================================================
   DELETE CONTENT
   DELETE /api/admin/content/:type/:id
============================================================================ */
export const deleteContent = async (req, res) => {
  try {
    const { type, id } = req.params;

    console.log("🔥 DELETE REQUEST:", { type, id });

    const table =
      type === "book" || type === "ebook" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" :
      null;

    if (!table)
      return res.status(400).json({ error: "Invalid type" });

    console.log("📌 Resolved table:", table);

    /* ==================== CASCADE DELETE ==================== */
    if (table === "mock_tests") {
      console.log("🧹 Deleting attempts for test:", id);

      const { error: attemptsErr } = await supabase
        .from("mock_attempts")
        .delete()
        .eq("test_id", id);

      if (attemptsErr)
        return res.status(400).json({ error: "Failed to delete attempts" });
    }

    /* ==================== DELETE CONTENT ==================== */
    const { error, count } = await supabase
      .from(table)
      .delete({ count: "exact" })
      .eq("id", id);

    if (error)
      return res.status(400).json({ error: "Failed to delete content" });

    console.log("✔️ Delete completed, count:", count);

    return res.json({
      message: "Content deleted",
      deleted: count
    });

  } catch (err) {
    console.error("🔥 deleteContent error:", err);
    return res.status(500).json({ error: "Server error deleting content" });
  }
};


/* ============================================================================
   EDIT CONTENT
============================================================================ */
export const editContent = async (req, res) => {
  try {
    const { type, id } = req.params;
    const updates = { ...req.body };

    const file = req.files?.file?.[0] || null;
    const cover = req.files?.cover?.[0] || null;

    const table =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" :
      null;

    if (!table)
      return res.status(400).json({ error: "Invalid type" });

    /* ==================== FILE REPLACE ==================== */
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;
      const { error } = await supabase.storage
        .from(table)
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
        });

      if (error)
        return res.status(400).json({ error: error.message });

      const { data } = supabase.storage
        .from(table)
        .getPublicUrl(filePath);

      updates.file_url = data?.publicUrl;
    }

    /* ==================== COVER REPLACE ==================== */
    if (cover) {
      const coverPath = `${Date.now()}-${cover.originalname}`;
      const { error } = await supabase.storage
        .from("covers")
        .upload(coverPath, cover.buffer, {
          contentType: cover.mimetype,
        });

      if (error)
        return res.status(400).json({ error: error.message });

      const { data } = supabase.storage
        .from("covers")
        .getPublicUrl(coverPath);

      updates.cover_url = data?.publicUrl;
    }

    /* ==================== UPDATE DB ==================== */
    const { data, error } = await supabase
      .from(table)
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error)
      return res.status(400).json({ error: error.message });

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
