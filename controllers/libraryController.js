import supabase from "../utils/supabaseClient.js";

/* ============================================
   📘 GET ALL BOOKS IN USER LIBRARY
============================================ */
export const getUserLibrary = async (req, res) => {
  const userId = req.user.id;

  // in getUserLibrary:
const { data, error } = await supabase
  .from("user_library")
  .select(`
    id,
    progress,
    last_page,
    added_at,
    book_id,
    ebooks:ebooks!inner (
      id,
      title,
      author,
      category,
      description,
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

  // Ensure book exists in ebooks table
  const { data: book } = await supabase
    .from("ebooks")
    .select("id")
    .eq("id", bookId)
    .maybeSingle();

  if (!book) return res.status(400).json({ error: "Book does not exist" });

  // Check if already added
  const { data: existing } = await supabase
    .from("user_library")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (existing)
    return res.json({ message: "Book already in library", alreadyAdded: true });

  // Insert new row
  const { error } = await supabase
    .from("user_library")
    .insert([{ user_id: userId, book_id: bookId, progress: 0 }]);

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
        file_url,
        pages,
        price,
        sales
      )
    `)
    .eq("user_id", userId)
    .lt("progress", 100)
    .gt("progress", 0);

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
          file_url,
          pages,
          price,
          sales
        )
      `)
      .eq("user_id", userId);

    if (error) throw error;

    // Manual case-insensitive filter
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
   📚 COLLECTIONS
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
      *,
      ebooks (
        id,
        title,
        author,
        category,
        description,
        file_url,
        pages,
        price,
        sales
      )
    `)
    .eq("collection_id", id);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
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

  const { error } = await supabase
    .from("collections")
    .delete()
    .eq("id", id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Collection deleted" });
};
/* ============================================
   📝 UPDATE READING PROGRESS
============================================ */
export const updateReadingProgress = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;
  const { progress } = req.body;

  const { error } = await supabase
    .from("user_library")
    .update({ progress })
    .eq("user_id", userId)
    .eq("book_id", bookId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Progress updated", progress });
};
export const startReading = async (req, res) => {
  const userId = req.user.id;
  const { book_id } = req.body;

  const { error } = await supabase
    .from("user_library")
    .update({ progress: 1 })  // mark started
    .eq("user_id", userId)
    .eq("book_id", book_id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Reading started" });
};
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
   📝 HIGHLIGHTS
   POST /api/library/highlights
   GET  /api/library/highlights/:bookId
   DELETE /api/library/highlights/:id
   Body for POST: { book_id, page, text, color, x?, y?, width?, height? }
============================================ */
export const saveHighlight = async (req, res) => {
  console.log("Incoming highlight data:", req.body);

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
  note = ""
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
      text: note
    }
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

    // convert DB fields to frontend naming convention
    const mapped = data.map(h => ({
      id: h.id,
      page: h.page,
      color: h.color,
      text: h.text,
      xPct: h.x,
      yPct: h.y,
      wPct: h.width,
      hPct: h.height
    }));

    res.json(mapped);
  } catch (err) {
    console.error("getHighlightsForBook error:", err);
    res.status(500).json({ error: "Failed to load highlights" });
  }
};


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
   📝 UPDATE READING PROGRESS (updated to store last_page)
   PUT /api/library/progress/:bookId
   Body optionally: { progress, currentPage }
============================================ */

