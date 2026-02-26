// controllers/bookController.js
import supabase from "../utils/pgClient.js";

/* ============================
   GET ALL BOOKS
============================= */
export const getAllBooks = async (req, res) => {
  try {
    const { category, search, sort } = req.query;

    let query = supabase
      .from("ebooks")
      .select("*")
      .order("created_at", { ascending: false });

    if (search) {
      query = query.or(`title.ilike.%${search}%,author.ilike.%${search}%`);
    }

    if (sort === "popular") {
      query = query.order("sales", { ascending: false });
    }

    const { data: books, error } = await query;
    if (error) throw error;

    const { data: catData } = await supabase.from("categories").select("id, name, slug");
    const catMap = {};
    if (catData) catData.forEach(c => catMap[c.id] = c);

    let formatted = books.map(b => ({
      ...b,
      categories: catMap[b.category_id] || null
    }));

    if (category && category !== "All") {
      formatted = formatted.filter(b => b.categories?.name === category);
    }

    res.json({ contents: formatted });
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
        id, title, author, description, price, file_url, rating, reviews, sales, category_id
      `)
      .eq("id", id)
      .maybeSingle();

    if (error) throw error;
    if (!book) return res.status(404).json({ error: "Book not found" });

    const { data: catData } = await supabase.from("categories").select("id, name, slug").eq("id", book.category_id).maybeSingle();
    book.categories = catData || null;

    return res.json({ book });
  } catch (err) {
    console.error("getBookById error:", err);
    return res.status(500).json({ error: "Book fetch failed" });
  }
};



/* ============================
   SEARCH BOOKS BY NAME
============================= */
export const searchBooksByName = async (req, res) => {
  try {
    const { name } = req.query;
    if (!name) return res.status(400).json({ error: "Book name query required" });

    const { data: books, error } = await supabase
      .from("ebooks")
      .select("*")
      .ilike("title", `%${name}%`);

    if (error) throw error;

    const { data: catData } = await supabase.from("categories").select("id, name, slug");
    const catMap = {};
    if (catData) catData.forEach(c => catMap[c.id] = c);

    const formatted = books.map(b => ({
      ...b,
      categories: catMap[b.category_id] || null
    }));

    res.json({ contents: formatted });
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
        book:ebooks ( * )
      `)
      .eq("user_id", userId)
      .order("added_at", { ascending: false });

    if (error) throw error;

    const { data: catData } = await supabase.from("categories").select("id, name, slug");
    const catMap = {};
    if (catData) catData.forEach(c => catMap[c.id] = c);

    const formatted = data.map(row => {
      if (row.book) {
        row.book.categories = catMap[row.book.category_id] || null;
      }
      return row;
    });

    res.json(formatted);
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
import { supabaseAdmin } from "../utils/pgClient.js";

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
       CHECK PURCHASE STATUS
       purchases table uses book_id
    ------------------------- */
    const { data: purchase, error: purchaseError } = await supabaseAdmin
      .from("book_sales")
      .select("id")
      .eq("user_id", userId)
      .eq("book_id", ebookId) // <-- FIXED
      .maybeSingle();

    if (purchaseError) throw purchaseError;

    if (!purchase) {
      return res.status(403).json({
        error: "You must purchase this ebook before rating it",
      });
    }

    /* -------------------------
       UPSERT USER RATING
    ------------------------- */
    const payload = {
      user_id: userId,
      ebook_id: ebookId, // this table uses ebook_id correctly
      rating,
      updated_at: new Date().toISOString(),
    };

    const { error: upsertError } = await supabaseAdmin
      .from("ebook_ratings")
      .upsert([payload], { onConflict: "user_id,ebook_id" });

    if (upsertError) throw upsertError;

    /* -------------------------
       RECALCULATE AVG + COUNT
    ------------------------- */
    const { data: ratings, error: fetchError } = await supabaseAdmin
      .from("ebook_ratings")
      .select("rating", { count: "exact" })
      .eq("ebook_id", ebookId);

    if (fetchError) throw fetchError;

    const reviews = ratings.length;
    const avg =
      reviews === 0
        ? 0
        : ratings.reduce((sum, r) => sum + r.rating, 0) / reviews;

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



