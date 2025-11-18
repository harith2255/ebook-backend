// controllers/admin/contentController.js
import supabase from "../../utils/supabaseClient.js"; // default admin client (service role)
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
    const file = req.file; // optional (Buffer)

    if (!type || !title || !author) {
      return res.status(400).json({ error: "type, title, and author are required" });
    }

    // map type -> table & bucket
    const table =
      type === "E-Book" ? "ebooks" :
      type === "Notes" ? "notes" :
      type === "Mock Test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid content type" });

    // If a file is provided, upload to bucket with same name as table
    let publicUrl = null;
    let pageCount = 0;

    if (file) {
      // store file in storage bucket (bucket name same as table)
      const filePath = `${Date.now()}-${file.originalname}`;

      const { error: uploadErr } = await supabase.storage
        .from(table)
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadErr) {
        console.error("Storage upload error:", uploadErr);
        return res.status(400).json({ error: uploadErr.message || "Storage upload failed" });
      }

      const { data: publicData } = supabase.storage.from(table).getPublicUrl(filePath);
      publicUrl = publicData?.publicUrl ?? null;

      // Count pages for PDFs (works for ebooks and notes)
      if (file.mimetype === "application/pdf") {
        try {
          pageCount = getPdfPageCount(file.buffer) || 0;
        } catch (err) {
          console.warn("pdf page count failed:", err);
          pageCount = 0;
        }
      }
    }

    // Build insert object for each table strictly matching schema

    let insertObj = null;

    if (table === "ebooks") {
      // EBOOKS schema (from you): id(uuid), title, author, category, description, pages(int),
      // price(numeric), sales(int), status(text), file_url(text), created_at(timestamptz), tags(array), summary(text), embedding(vector)
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
        created_at: new Date().toISOString(),
        tags: [],         // empty array
        summary: "",
        embedding: null,  // null vector
      };
    } else if (table === "notes") {
      // NOTES schema (from you): id(bigint), title, category, author, pages, downloads, rating, price,
      // featured(bool), file_url, preview_content, created_at, updated_at, description, tags, summary, embedding
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
        preview_content: "",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        description: description || null,
        tags: [],
        summary: "",
        embedding: null,
      };
    } else if (table === "mock_tests") {
      // MOCK_TESTS schema you provided:
      // id(bigint), title(text), scheduled_date(timestamptz), total_questions(int),
      // duration_minutes(int), created_at(timestamp), subject(text), difficulty(text), participants(int)
      //
      // NOTE: your mock_tests schema does not include file_url. We will not attempt to insert file_url to avoid column errors.
      // If you'd like to store uploaded file URL, add a `file_url text` column to mock_tests (SQL shown below).
      const scheduled_date = req.body.scheduled_date ? new Date(req.body.scheduled_date).toISOString() : new Date().toISOString();
      const total_questions = req.body.total_questions ? Number(req.body.total_questions) : 0;
      const duration_minutes = req.body.duration_minutes ? Number(req.body.duration_minutes) : 0;
      const difficulty = req.body.difficulty || "Medium";
      const subject = req.body.subject || category || "Agriculture";

      insertObj = {
        title,
        scheduled_date,
        total_questions,
        duration_minutes,
        created_at: new Date().toISOString(),
        subject,
        difficulty,
        participants: 0,
        // intentionally NOT inserting file_url because schema doesn't have it
      };
    }

    // Perform insert (we use the service-role client so RLS won't block the insert)
    const { data, error } = await supabase
      .from(table)
      .insert([insertObj])
      .select()
      .single();

    if (error) {
      console.error("Insert error:", error);
      // pass error message from supabase where possible
      return res.status(400).json({ error: error.message || "Insert failed" });
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

    const table =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    const { error } = await supabase.from(table).delete().eq("id", id);

    if (error) {
      console.error("deleteContent supabase error:", error);
      return res.status(400).json({ error: error.message || "Delete failed" });
    }

    // Optionally remove file from storage? We don't know file path here.
    return res.json({ message: "Content deleted" });
  } catch (err) {
    console.error("deleteContent error:", err);
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
    const file = req.file;

    const table =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    // Normalize tags if present (string -> array)
    if (updates.tags && typeof updates.tags === "string") {
      updates.tags = updates.tags.split(",").map((t) => t.trim());
    }

    // If file is provided, upload but only set file_url for ebooks/notes (mock_tests has no file_url in schema)
    let file_url = null;
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;
      const { error: uploadErr } = await supabase.storage.from(table).upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

      if (uploadErr) {
        console.error("edit file upload error:", uploadErr);
        return res.status(400).json({ error: uploadErr.message || "Storage upload failed" });
      }

      const { data: publicData } = supabase.storage.from(table).getPublicUrl(filePath);
      file_url = publicData?.publicUrl ?? null;

      // If PDF, we can recompute pages for ebooks/notes
      if (file.mimetype === "application/pdf" && (table === "ebooks" || table === "notes")) {
        try {
          const pageCount = getPdfPageCount(file.buffer);
          updates.pages = pageCount || updates.pages;
        } catch (err) {
          console.warn("edit pdf page count failed:", err);
        }
      }
    }

    // Only attach file_url when table supports it (ebooks, notes)
    if (file_url && (table === "ebooks" || table === "notes")) {
      updates.file_url = file_url;
    }

    // For safety: remove fields that could cause errors for mock_tests
    if (table === "mock_tests") {
      // Allowed columns based on schema: title, scheduled_date, total_questions, duration_minutes, subject, difficulty, participants, created_at
      const allowed = ["title", "scheduled_date", "total_questions", "duration_minutes", "subject", "difficulty", "participants"];
      Object.keys(updates).forEach((k) => {
        if (!allowed.includes(k)) delete updates[k];
      });
    }

    // Perform update
    const { data, error } = await supabase
      .from(table)
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error) {
      console.error("editContent supabase error:", error);
      return res.status(400).json({ error: error.message || "Update failed" });
    }

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
