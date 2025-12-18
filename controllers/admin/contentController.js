import { supabaseAdmin } from "../../utils/supabaseClient.js";

import getPdfPageCount from "../../utils/pdfReader.js";

/* ============================================================================
   UPLOAD CONTENT
   POST /api/admin/content/upload
============================================================================ */

const slugify = (str = "") =>
  str
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-");

export const uploadContent = async (req, res) => {
  try {
   const rawType = String(req.body.type || "").trim();
const typeKey = rawType.toLowerCase();


    const title = req.body.title || "";
    const author = req.body.author || "";
    const rawCategory = req.body.category || null;
    let categoryId = null;

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

    // ---------------------------
    // BASIC VALIDATION
    // ---------------------------
  if (!rawType || !title) {
  return res.status(400).json({ error: "type and title are required" });
}

if (rawType !== "Mock Test" && !author) {
  return res.status(400).json({
    error: "author is required for E-Book and Notes",
  });
}


  

const table =
 ["book", "books", "ebook", "ebooks", "e-book", "e-books"].includes(typeKey)
    ? "ebooks"
    : ["note", "notes"].includes(typeKey)
    ? "notes"
    : ["mock test", "mock_tests", "test", "tests"].includes(typeKey)
    ? "mock_tests"
    : null;



    if (!table) {
      return res.status(400).json({ error: "Invalid content type" });
    }

    let publicUrl = null;
    let coverUrl = null;
    let pageCount = 0;



    /* ==================== CATEGORY AUTO CREATE ==================== */
if (rawCategory) {
  const cleanCategory = rawCategory.trim();
  const slug = slugify(cleanCategory);

  // Check if category exists
  const { data: existingCategory } = await supabaseAdmin
    .from("categories")
    .select("id")
    .eq("slug", slug)
    .single();

  if (existingCategory) {
    categoryId = existingCategory.id;
  } else {
    // Create category
    const { data: newCategory, error: catErr } = await supabaseAdmin
      .from("categories")
      .insert({
        name: cleanCategory,
        slug,
      })
      .select()
      .single();

    if (catErr) {
      console.error("Category insert error:", catErr);
      return res.status(400).json({ error: "Failed to create category" });
    }

    categoryId = newCategory.id;
  }
}



    /* ==================== FILE UPLOAD ==================== */
    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;

      const { error: uploadErr } = await supabaseAdmin.storage
        .from(table)
        .upload(filePath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });

      if (uploadErr) {
        console.error("File upload error:", uploadErr);
        return res.status(400).json({ error: uploadErr.message });
      }

      const { data: publicData } = supabaseAdmin.storage
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

      const { error: coverErr } = await supabaseAdmin.storage
        .from("covers")
        .upload(coverPath, cover.buffer, {
          contentType: cover.mimetype,
          upsert: false,
        });

      if (coverErr) {
        console.error("Cover upload error:", coverErr);
        return res.status(400).json({ error: coverErr.message });
      }

      const { data: coverData } = supabaseAdmin.storage
        .from("covers")
        .getPublicUrl(coverPath);

      coverUrl = coverData?.publicUrl || null;
    }

    /* ==================== BUILD INSERT OBJ ==================== */
    let insertObj = {};

    if (table === "ebooks") {
      insertObj = {
        title,
        author,
         category_id: categoryId,
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
        category_id: categoryId,
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
      // EXTRA VALIDATION FOR MOCK TESTS
      const rawTotalQs = req.body.total_questions;
      const rawDuration = req.body.duration_minutes;

      if (!rawTotalQs) {
        return res
          .status(400)
          .json({ error: "total_questions is required for Mock Test" });
      }
      if (!rawDuration) {
        return res
          .status(400)
          .json({ error: "duration_minutes is required for Mock Test" });
      }

      const totalQs = Number(rawTotalQs);
      const duration = Number(rawDuration);

      if (!Number.isFinite(totalQs) || totalQs <= 0) {
        return res
          .status(400)
          .json({ error: "Invalid total_questions value" });
      }

      if (!Number.isFinite(duration) || duration <= 0) {
        return res
          .status(400)
          .json({ error: "Invalid duration_minutes value" });
      }

      const scheduled = req.body.scheduled_date || null;

      insertObj = {
        title,
        subject: req.body.subject || null,
        difficulty: req.body.difficulty || null,
        total_questions: totalQs,
        duration_minutes: duration,
        start_time: scheduled, // DB uses start_time (NOT scheduled_date)
        description,
        participants: 0,
        created_at: new Date().toISOString(),
      };
    }

    /* ==================== INSERT MAIN ROW ==================== */
    const { data: insertData, error: insertError } = await supabaseAdmin
      .from(table)
      .insert(insertObj)
      .select()
      .single();

    if (insertError) {
      console.error("Insert error:", insertError);
      return res.status(400).json({ error: insertError.message });
    }

    /* ==================== INSERT MCQs (for Mock Test) ==================== */
    /* ==================== INSERT MCQs (for Mock Test) ==================== */
if (rawType === "Mock Test" && Array.isArray(mcqs) && mcqs.length > 0) {
  const testId = insertData.id;

  const questionRows = mcqs.map((mcq) => ({
    test_id: testId,
    question: mcq.question || "",
    option_a: mcq.options?.[0] || null,
    option_b: mcq.options?.[1] || null,
    option_c: mcq.options?.[2] || null,
    option_d: mcq.options?.[3] || null,
    option_e: mcq.options?.[4] || null,   // ✅ FIXED (Previously missing)
    correct_option: mcq.answer || "",
    explanation: mcq.explanation || null  // ✅ FIXED
  }));

  const { error: qErr } = await supabaseAdmin
    .from("mock_test_questions")
    .insert(questionRows);

  if (qErr) {
    console.error("MCQ insert error:", qErr);
    return res.status(400).json({
      error: "Mock test created, but MCQ insert failed",
      details: qErr.message,
    });
  }

  console.log(`Inserted ${questionRows.length} MCQs for test ${testId}`);
}


    /* ==================== SUCCESS RESPONSE ==================== */
    return res.status(201).json({
      message: "Content uploaded",
      data: insertData,
    });
  } catch (err) {
    console.error("uploadContent error:", err);
    return res
      .status(500)
      .json({ error: "Server error uploading content" });
  }
};


/* ============================================================================
   LIST CONTENT
   GET /api/admin/content?type=books|notes|tests
============================================================================ */
export const listContent = async (req, res) => {
  try {
    const rawType = String(req.query.type || "").toLowerCase().trim();

    const table =
      ["book", "books", "ebook", "ebooks"].includes(rawType)
        ? "ebooks"
        : ["note", "notes"].includes(rawType)
        ? "notes"
        : ["test", "tests", "mock_test", "mock_tests"].includes(rawType)
        ? "mock_tests"
        : null;

    if (!table) {
      return res.status(400).json({ error: "Invalid type" });
    }

    // MOCK TESTS (no categories)
    if (table === "mock_tests") {
      const { data, error } = await supabaseAdmin
        .from("mock_tests")
        .select("*")
        .order("created_at", { ascending: false });

      if (error) return res.status(400).json({ error: error.message });
      return res.json({ contents: data });
    }

    // ✅ BOOKS + NOTES (JOIN categories)
    const { data, error } = await supabaseAdmin
      .from(table)
      .select(`
        *,
        categories (
          id,
          name,
          slug
        )
      `)
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

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
const rawType = String(type || "").toLowerCase().trim();


const table =
  ["book", "ebook", "ebooks"].includes(rawType)
    ? "ebooks"
    : ["note", "notes"].includes(rawType)
    ? "notes"
    : ["test", "tests", "mock_test", "mock_tests"].includes(rawType)
    ? "mock_tests"
    : null;

if (!table) {
  return res.status(400).json({ error: "Invalid content type" });
}

console.log("🧨 Deleting from table:", table, "ID:", id);

    if (table === "ebooks") {

      // Delete from collections
      await supabaseAdmin.from("collection_books")
        .delete()
        .eq("book_id", id);

      // Delete from user library
      await supabaseAdmin.from("user_library")
        .delete()
        .eq("book_id", id);

      // Delete highlights
      await supabaseAdmin.from("highlights")
        .delete()
        .eq("book_id", id);
    }

    const { error, count } = await supabaseAdmin
      .from(table)
      .delete({ count: "exact" })
      .eq("id", id);

    if (error) {
      console.error("Supabase delete error:", error);
      return res.status(400).json({ error: error.message });
    }

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
    const rawType = type.toLowerCase();

    const table =
      ["book", "ebook", "ebooks"].includes(rawType)
        ? "ebooks"
        : ["note", "notes"].includes(rawType)
        ? "notes"
        : ["test", "tests", "mock_test", "mock_tests"].includes(rawType)
        ? "mock_tests"
        : null;

    if (!table) {
      return res.status(400).json({ error: "Invalid type" });
    }

    const updates = {};

    const allowedFields = {
      ebooks: ["title", "author", "description", "price", "status"],
      notes: ["title", "author", "description", "price", "featured"],
      mock_tests: [
        "title",
        "subject",
        "difficulty",
        "total_questions",
        "duration_minutes",
        "start_time",
        "description",
      ],
    };

    /* ================= CATEGORY UPDATE (AUTO CREATE) ================= */
    if (req.body.category && table !== "mock_tests") {
      const cleanCategory = req.body.category.trim();
      const slug = slugify(cleanCategory);

      let { data: category } = await supabaseAdmin
        .from("categories")
        .select("id")
        .eq("slug", slug)
        .single();

      if (!category) {
        const { data: newCat, error } = await supabaseAdmin
          .from("categories")
          .insert({ name: cleanCategory, slug })
          .select()
          .single();

        if (error) {
          return res
            .status(400)
            .json({ error: "Failed to create category" });
        }

        category = newCat;
      }

      updates.category_id = category.id;
    }

    /* ================= NORMAL FIELD UPDATES ================= */
    for (const key of allowedFields[table]) {
      if (req.body[key] !== undefined && req.body[key] !== "") {
        updates[key] =
          key === "price" ? Number(req.body[key]) : req.body[key];
      }
    }

    /* ================= FILE UPLOAD ================= */
    const file = req.files?.file?.[0];
    const cover = req.files?.cover?.[0];

    if (file) {
      const filePath = `${Date.now()}-${file.originalname}`;

      await supabaseAdmin.storage.from(table).upload(filePath, file.buffer, {
        contentType: file.mimetype,
      });

      const { data } = supabaseAdmin.storage
        .from(table)
        .getPublicUrl(filePath);

      updates.file_url = data?.publicUrl;

      if (file.mimetype === "application/pdf") {
        updates.pages = getPdfPageCount(file.buffer);
      }
    }

    if (cover) {
      const coverPath = `${Date.now()}-${cover.originalname}`;

      await supabaseAdmin.storage
        .from("covers")
        .upload(coverPath, cover.buffer, {
          contentType: cover.mimetype,
        });

      const { data } = supabaseAdmin.storage
        .from("covers")
        .getPublicUrl(coverPath);

      updates.cover_url = data?.publicUrl;
    }

    /* ================= NOTHING TO UPDATE ================= */
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ error: "No fields to update" });
    }

    /* ================= DB UPDATE ================= */
    const { data, error } = await supabaseAdmin
      .from(table)
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
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
