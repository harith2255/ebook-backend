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
      .select("*")
      .order("created_at", { ascending: false });

    if (category && category !== "All") {
      query = query.eq("category", category);
    }

    if (search) {
      query = query.or(`title.ilike.%${search}%,author.ilike.%${search}%`);
    }

    if (sort === "popular") {
      query = query.order("sales", { ascending: false });
    }

    const { data, error } = await query;
    if (error) throw error;

    res.json(data);
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
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;
    if (!book) return res.status(404).json({ error: "Book not found" });

    res.json(book);
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
    if (!name) return res.status(400).json({ error: "Book name query required" });

    const { data, error } = await supabase
      .from("ebooks")
      .select("*")
      .ilike("title", `%${name}%`);

    if (error) throw error;
    res.json(data);
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
        book:ebooks(*)
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
    const { bookId, progress } = req.body;

    const { error } = await supabase
      .from("user_library")
      .update({ progress, last_read: new Date().toISOString() })
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) throw error;

    res.json({ success: true });
  } catch (err) {
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