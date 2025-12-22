// controllers/bookController.js
import supabase from "../utils/supabaseClient.js";

/* ============================
   GET ALL BOOKS
============================= */
export const getAllBooks = async (req, res) => {
  try {
    const { category, search, sort } = req.query;

    let query = supabase
      .from("ebooks")
      .select(`
        *,
        categories:category_id (
          id,
          name,
          slug
        )
      `)
      .order("created_at", { ascending: false });

    // ✅ Category filter (relation-safe)
    if (category && category !== "All") {
      query = query.eq("categories.name", category);
    }

    // ✅ Search
    if (search) {
      query = query.or(
        `title.ilike.%${search}%,author.ilike.%${search}%`
      );
    }

    // ✅ Sort
    if (sort === "popular") {
      query = query.order("sales", { ascending: false });
    }

    const { data, error } = await query;
    if (error) throw error;

    res.json({ contents: data });
  } catch (err) {
    console.error("getAllBooks error:", err);
    res.status(500).json({ error: err.message });
  }
};



/* ============================
   GET BOOK BY ID
============================= */
export const getBookById = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: book, error } = await supabase
      .from("ebooks")
      .select(`
        *,
        categories (
          id,
          name,
          slug
        )
      `)
      .eq("id", id)
      .single();

    if (error) throw error;
    if (!book) return res.status(404).json({ error: "Book not found" });

    res.json({ book });
  } catch (err) {
    console.error("getBookById error:", err);
    res.status(404).json({ error: "Book not found" });
  }
};


/* ============================
   SEARCH BOOKS BY NAME
============================= */
export const searchBooksByName = async (req, res) => {
  try {
    const { name } = req.query;
    if (!name)
      return res.status(400).json({ error: "Book name query required" });

    const { data, error } = await supabase
      .from("ebooks")
      .select(`
        *,
        categories (
          id,
          name,
          slug
        )
      `)
      .ilike("title", `%${name}%`);

    if (error) throw error;
    res.json({ contents: data });
  } catch (err) {
    console.error("Error searching books:", err.message);
    res.status(500).json({ error: "Failed to search books" });
  }
};


/* ============================
   GET USER'S LIBRARY
============================= */
export const getUserLibrary = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("user_library")
      .select(`
        *,
        book:ebooks (
          *,
          categories (
            id,
            name,
            slug
          )
        )
      `)
      .eq("user_id", userId)
      .order("added_at", { ascending: false });

    if (error) throw error;

    res.json(data);
  } catch (err) {
    console.error("getUserLibrary error:", err);
    res.status(500).json({ error: err.message });
  }
};


/* ============================
   UPDATE READING PROGRESS
============================= */
export const updateProgress = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;   // ✔ from URL
    const { progress } = req.body;   // ✔ from body

    if (!progress && progress !== 0) {
      return res.status(400).json({ error: "Progress value required" });
    }

    const { error } = await supabase
      .from("user_library")
      .update({
        progress,
        last_read: new Date().toISOString(),
        completed_at: progress === 100 ? new Date().toISOString() : null
      })
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) throw error;

    res.json({ success: true, progress });
  } catch (err) {
    console.error("updateProgress error:", err);
    res.status(500).json({ error: err.message });
  }
};


/* ============================
   LOG BOOK READ EVENT (DRM)
============================= */
export const logBookRead = async (req, res) => {
  try {
    const userId = req.user?.id;
    const { book_id } = req.body;

    if (!book_id) {
      return res.status(400).json({ error: "book_id required" });
    }

    // Get user info
    const { data: user } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", userId)
      .maybeSingle();

    // Get book info
    const { data: book } = await supabase
      .from("ebooks")
      .select("title")
      .eq("id", book_id)
      .maybeSingle();

    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: user?.full_name || "Unknown User",
      book_id,
      book_title: book?.title || "Unknown Book",
      action: "read",
      device_info: req.headers["user-agent"] || "Unknown Device",
      ip_address: req.ip,
      created_at: new Date(),
    });

    res.json({ message: "Read logged" });

  } catch (err) {
    console.error("logBookRead error:", err);
    res.status(500).json({ error: "Could not log read action" });
  }
};
import { supabaseAdmin } from "../utils/supabaseClient.js";

/* ======================================================
   RATE EBOOK
   POST /api/ebooks/:id/rate
====================================================== */
export const rateEbook = async (req, res) => {
  try {
    const ebookId = req.params.id;
    const userId = req.user.id;
    const { rating } = req.body;

    /* -------------------------
       VALIDATION
    ------------------------- */
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({ error: "Rating must be 1–5" });
    }

    /* -------------------------
       UPSERT USER RATING
    ------------------------- */
    const { error: upsertError } = await supabaseAdmin
      .from("ebook_ratings")
      .upsert(
        {
          user_id: userId,
          ebook_id: ebookId,
          rating,
          updated_at: new Date(),
        },
        { onConflict: "user_id,ebook_id" }
      );

    if (upsertError) throw upsertError;

    /* -------------------------
       RECALCULATE AVG + COUNT
    ------------------------- */
    const { data, error: fetchError } = await supabaseAdmin
      .from("ebook_ratings")
      .select("rating", { count: "exact" })
      .eq("ebook_id", ebookId);

    if (fetchError) throw fetchError;

    const reviews = data.length;
    const avg =
      reviews === 0
        ? 0
        : data.reduce((sum, r) => sum + r.rating, 0) / reviews;

    /* -------------------------
       UPDATE EBOOK TABLE
    ------------------------- */
    const { error: updateError } = await supabaseAdmin
      .from("ebooks")
      .update({
        rating: avg.toFixed(2),
        reviews,
      })
      .eq("id", ebookId);

    if (updateError) throw updateError;

    res.json({
      message: "Rating saved successfully",
      rating: Number(avg.toFixed(2)),
      reviews,
    });
  } catch (err) {
    console.error("Ebook rating error:", err);
    res.status(500).json({ error: "Failed to save rating" });
  }
};
