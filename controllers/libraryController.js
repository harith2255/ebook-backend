import supabase from "../utils/supabaseClient.js";

/* ============================================
   📘 GET ALL BOOKS IN USER LIBRARY
============================================ */
export const getUserLibrary = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_library")
    .select(`
      id,
      progress,
      last_page,
      added_at,
      book_id,
     ebooks: ebooks!inner (
  id,
  title,
  author,
  category,
  description,
  cover_url,
  file_url,
  pages,
  price,
  sales
)

    `)
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ============================================
   ➕ ADD BOOK TO LIBRARY
============================================ */
export const addBookToLibrary = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;

  const { data: book } = await supabase
    .from("ebooks")
    .select("id")
    .eq("id", bookId)
    .maybeSingle();

  if (!book) return res.status(400).json({ error: "Book does not exist" });

  const { data: existing } = await supabase
    .from("user_library")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (existing)
    return res.json({ message: "Book already in library", alreadyAdded: true });

  const { error } = await supabase
    .from("user_library")
    .insert([{ user_id: userId, book_id: bookId, progress: 0, last_page: 1 }]);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Book added to library", alreadyAdded: false });
};

/* ============================================
   ❌ REMOVE BOOK FROM LIBRARY
============================================ */
export const removeBookFromLibrary = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;

  const { error } = await supabase
    .from("user_library")
    .delete()
    .eq("user_id", userId)
    .eq("book_id", bookId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Book removed from library" });
};

/* ============================================
   🆕 RECENTLY ADDED BOOKS
============================================ */
export const getRecentBooks = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_library")
    .select(`
      id,
      progress,
      added_at,
      ebooks (
        id,
        title,
        author,
        category,
        description,
        cover_url,
        file_url,
        pages,
        price,
        sales
      )
    `)
    .eq("user_id", userId)
    .order("added_at", { ascending: false })
    .limit(5);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ============================================
   📖 CURRENTLY READING
============================================ */
export const getCurrentlyReading = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_library")
    .select(`
      id,
      progress,
      added_at,
      ebooks (
        id,
        title,
        author,
        category,
        description,
        cover_url,
        file_url,
        pages,
        price,
        sales
      )
    `)
    .eq("user_id", userId)
    .gt("progress", 0)
    .lt("progress", 100);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ============================================
   ✅ COMPLETED BOOKS
============================================ */
export const getCompletedBooks = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("user_library")
    .select(`
      id,
      progress,
      added_at,
      ebooks (
        id,
        title,
        author,
        category,
        description,
        cover_url,
        file_url,
        pages,
        price,
        sales
      )
    `)
    .eq("user_id", userId)
    .eq("progress", 100);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

/* ============================================
   🔍 SEARCH LIBRARY
============================================ */
export const searchLibrary = async (req, res) => {
  try {
    const userId = req.user.id;
    const { query } = req.query;

    const { data, error } = await supabase
      .from("user_library")
      .select(`
        id,
        progress,
        added_at,
        ebooks (
          id,
          title,
          author,
          category,
          description,
          cover_url,
          file_url,
          pages,
          price,
          sales
        )
      `)
      .eq("user_id", userId);

    if (error) throw error;

    const filtered = data.filter((entry) =>
      entry.ebooks?.title?.toLowerCase().includes(query.toLowerCase())
    );

    res.json(filtered);
  } catch (err) {
    console.error("Search error:", err.message);
    res.status(500).json({ error: "Failed to search library" });
  }
};

/* ============================================
   📚 COLLECTIONS (Create, Read, Manage)
============================================ */
export const createCollection = async (req, res) => {
  const userId = req.user.id;
  const { name } = req.body;

  const { error } = await supabase
    .from("collections")
    .insert([{ user_id: userId, name }]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Collection created" });
};

export const getAllCollections = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("collections")
    .select("*")
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

export const getCollectionBooks = async (req, res) => {
  const { id } = req.params;

  const { data, error } = await supabase
    .from("collection_books")
    .select(`
      book_id,
      ebooks:ebooks (
        id,
        title,
        author,
        category,
        description,
        cover_url,
        file_url,
        pages,
        price
      )
    `)
    .eq("collection_id", id);

  if (error) return res.status(400).json({ error: error.message });

  // Flatten response so UI works
  const formatted = data.map((item) => ({
    id: item.ebooks.id,
    title: item.ebooks.title,
    author: item.ebooks.author,
    category: item.ebooks.category,
    description: item.ebooks.description,
    cover_url: item.ebooks.cover_url,
    file_url: item.ebooks.file_url,
    pages: item.ebooks.pages,
    price: item.ebooks.price,
    progress: 0, // optional, library progress not stored here
    purchased: null, // optional
  }));

  res.json(formatted);
};

export const addBookToCollection = async (req, res) => {
  const { id, bookId } = req.params;

  const { error } = await supabase
    .from("collection_books")
    .insert([{ collection_id: id, book_id: bookId }]);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Book added to collection" });
};

export const removeBookFromCollection = async (req, res) => {
  const { id, bookId } = req.params;

  const { error } = await supabase
    .from("collection_books")
    .delete()
    .eq("collection_id", id)
    .eq("book_id", bookId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Book removed from collection" });
};

export const deleteCollection = async (req, res) => {
  const { id } = req.params;

  const { error } = await supabase.from("collections").delete().eq("id", id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Collection deleted" });
};

/* ============================================
   🔥 SMART UPDATE READING PROGRESS
============================================ */
export const updateReadingProgress = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;
    const { progress } = req.body;

    if (typeof progress !== "number") {
      return res.status(400).json({ error: "Invalid 'progress' — expected number" });
    }

    const now = new Date().toISOString();

    // Only update allowed columns that exist in DB
    const updates = {
      progress,
      completed_at: progress === 100 ? now : null
    };

    // Make sure the user_library row exists for this user & book
    const { data: existing, error: selErr } = await supabase
      .from("user_library")
      .select("id")
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .maybeSingle();

    if (selErr) {
      console.error("Supabase select error (updateReadingProgress):", selErr);
      return res.status(500).json({ error: "Database error" });
    }

    if (!existing) {
      return res.status(404).json({ error: "Library entry not found for this user/book" });
    }

    const { error } = await supabase
      .from("user_library")
      .update(updates)
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) {
      console.error("🔥 SUPABASE UPDATE ERROR (updateReadingProgress):", error);
      return res.status(400).json({ error: error.message, details: error });
    }

    // If you have a global dashboard refresh, call it
    globalThis.dispatchDashboardUpdate?.();

    res.json({
      message: "Progress updated",
      progress,
      completed: progress === 100,
    });
  } catch (err) {
    console.error("updateReadingProgress error:", err);
    res.status(500).json({ error: "Failed to update reading progress" });
  }
};




/* ============================================
   📝 START READING
============================================ */
export const startReading = async (req, res) => {
  const userId = req.user.id;
  const { book_id } = req.body;

  const { error } = await supabase
    .from("user_library")
    .update({ progress: 1 })
    .eq("user_id", userId)
    .eq("book_id", book_id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Reading started" });
};

/* ============================================
   🎯 MARK COMPLETED
============================================ */
export const markBookCompleted = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;

  const { error } = await supabase
    .from("user_library")
    .update({ progress: 100 })
    .eq("user_id", userId)
    .eq("book_id", bookId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Book marked completed" });
};

/* ============================================
   📝 SAVE HIGHLIGHT
============================================ */
export const saveHighlight = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      book_id,
      page,
      x_pct,
      y_pct,
      w_pct,
      h_pct,
      color = "rgba(255,255,0,0.35)",
      note = "",
    } = req.body;

    const { data, error } = await supabase
      .from("highlights")
      .insert([
        {
          user_id: userId,
          book_id,
          page,
          x: x_pct,
          y: y_pct,
          width: w_pct,
          height: h_pct,
          color,
          text: note,
        },
      ])
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    res.json(data);
  } catch (err) {
    console.error("saveHighlight error:", err);
    res.status(500).json({ error: "Failed to save highlight" });
  }
};

/* ============================================
   📚 GET HIGHLIGHTS BY BOOK
============================================ */
export const getHighlightsForBook = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;

    const { data, error } = await supabase
      .from("highlights")
      .select("*")
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) return res.status(400).json({ error: error.message });

    const mapped = data.map((h) => ({
      id: h.id,
      page: h.page,
      color: h.color,
      text: h.text,
      xPct: h.x,
      yPct: h.y,
      wPct: h.width,
      hPct: h.height,
    }));

    res.json(mapped);
  } catch (err) {
    console.error("getHighlightsForBook error:", err);
    res.status(500).json({ error: "Failed to load highlights" });
  }
};

/* ============================================
   🗑 DELETE HIGHLIGHT
============================================ */
export const deleteHighlight = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const { error } = await supabase
      .from("highlights")
      .delete()
      .eq("id", id)
      .eq("user_id", userId);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Highlight deleted" });
  } catch (err) {
    console.error("deleteHighlight error:", err);
    res.status(500).json({ error: "Failed to delete highlight" });
  }
};

/* ============================================
   📖 GET LAST PAGE
============================================ */
export const getLastPage = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;

    const { data, error } = await supabase
      .from("user_library")
      .select("last_page")
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .maybeSingle();

    if (error) return res.status(400).json({ error: error.message });

    res.json({ last_page: data?.last_page || 1 });
  } catch (err) {
    console.error("getLastPage error:", err);
    res.status(500).json({ error: "Failed to load last page" });
  }
};

/* ============================================
   📖 SAVE LAST PAGE
============================================ */
export const saveLastPage = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;
    const { last_page } = req.body;

    const { error } = await supabase
      .from("user_library")
      .update({ last_page })
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Last page saved", last_page });
  } catch (err) {
    console.error("saveLastPage error:", err);
    res.status(500).json({ error: "Failed to save last page" });
  }
};

/* ============================================
   ✏️ RENAME COLLECTION
============================================ */
export const renameCollection = async (req, res) => {
  const { id } = req.params;
  const { name } = req.body;

  const { error } = await supabase
    .from("collections")
    .update({ name })
    .eq("id", id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Collection renamed" });
};

/* ============================================
   ⏱ SAVE STUDY SESSION
============================================ */
export const saveStudySession = async (req, res) => {
  try {
    const userId = req.user.id;
    const { duration } = req.body; // duration in HOURS

    if (!duration || duration <= 0) {
      return res.status(400).json({ error: "Invalid duration" });
    }

    const { error } = await supabase
      .from("study_sessions")
      .insert([{ user_id: userId, duration }]);

    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Study session saved", duration });
  } catch (err) {
    console.error("saveStudySession error:", err);
    res.status(500).json({ error: "Failed to save study session" });
  }
};

