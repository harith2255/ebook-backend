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
  try {
    const collectionId = req.params.id;

    const { data, error } = await supabase
      .from("collection_books")
      .select(`
        book_id,
        ebooks (
          id,
          title,
          author,
          category,
          cover_url,
          pages
        )
      `)
      .eq("collection_id", collectionId);

    if (error) throw error;

    const books = (data || [])
      .filter((entry) => entry.ebooks !== null)
      .map((entry) => ({
        id: entry.ebooks.id,
        title: entry.ebooks.title,
        author: entry.ebooks.author,
        category: entry.ebooks.category,
        cover_url: entry.ebooks.cover_url || "https://placehold.co/300x400",
        pages: entry.ebooks.pages,
      }));

    res.json(books);
  } catch (err) {
    console.error("ERROR getCollectionBooks:", err);
    res.status(500).json({ error: "Failed to fetch collection books" });
  }
};

export const addBookToCollection = async (req, res) => {
  try {
    const collectionId = req.params.id;
    const { book_id } = req.body;

    if (!book_id) {
      return res.status(400).json({ error: "book_id is required" });
    }

    // 👉 1️⃣ Check if already exists
    const { data: existing, error: existingErr } = await supabase
      .from("collection_books")
      .select("id")
      .eq("collection_id", collectionId)
      .eq("book_id", book_id)
      .maybeSingle();

    if (existingErr) throw existingErr;

    if (existing) {
      return res.json({
        message: "Book already in this collection",
        alreadyAdded: true,
      });
    }

    // 👉 2️⃣ Insert only if not exists
    const { error } = await supabase.from("collection_books").insert({
      collection_id: collectionId,
      book_id: book_id,
    });

    if (error) throw error;

    res.json({ message: "Book added to collection", alreadyAdded: false });
  } catch (err) {
    console.error("ADD BOOK TO COLLECTION ERROR:", err);
    res.status(500).json({ error: "Failed to add book" });
  }
};

export const deleteCollection = async (req, res) => {
  try {
    const collectionId = req.params.id;

    // Delete books inside collection
    await supabase.from("collection_books").delete().eq("collection_id", collectionId);

    // Delete collection
    await supabase.from("collections").delete().eq("id", collectionId);

    res.json({ message: "Collection deleted successfully" });
  } catch (err) {
    console.error("DELETE COLLECTION ERROR:", err);
    res.status(500).json({ error: "Failed to delete collection" });
  }
};
/* ============================================
   ❌ REMOVE BOOK FROM COLLECTION
============================================ */
export const removeBookFromCollection = async (req, res) => {
  try {
    const { id: collectionId, bookId } = req.params;

    const { error } = await supabase
      .from("collection_books")
      .delete()
      .eq("collection_id", collectionId)
      .eq("book_id", bookId);

    if (error) throw error;

    res.json({ message: "Book removed from collection" });
  } catch (err) {
    res.status(500).json({ error: "Failed to remove book" });
  }
};
/* ============================================
   ✏️ UPDATE COLLECTION NAME
============================================ */
export const updateCollection = async (req, res) => {
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
   🔥 SMART UPDATE READING PROGRESS
============================================ */
export const updateReadingProgress = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.params;
    let { progress, last_page } = req.body;

    if (typeof progress !== "number" || progress < 0)
      return res.status(400).json({ error: "Invalid progress" });

    if (!last_page || last_page < 1) last_page = 1;

    // convert fractional value
    if (progress > 0 && progress < 1) {
      progress = progress * 100;
    }

    progress = Math.min(100, Math.round(progress));

    const now = new Date().toISOString();

    const { data: existing, error: exErr } = await supabase
      .from("user_library")
      .select("id, progress")
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .maybeSingle();

    if (exErr) return res.status(400).json({ error: exErr.message });

    if (!existing)
      return res.status(404).json({ error: "Not in library" });

    // ignore regression
    if (progress < existing.progress) {
      return res.json({
        message: "Ignored regression",
        progress: existing.progress,
        last_page,
      });
    }

    const { error } = await supabase
      .from("user_library")
      .update({
        progress,
        last_page,
        completed_at: progress === 100 ? now : null,
      })
      .eq("user_id", userId)
      .eq("book_id", bookId);

    if (error) return res.status(400).json({ error: error.message });

    return res.json({
      message: "Progress updated",
      progress,
      last_page,
      completed: progress === 100,
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to update progress" });
  }
};



export const getCollectionBookIds = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("collection_books")
      .select("book_id");

    if (error) {
      console.error("getCollectionBookIds error:", error);
      return res.status(400).json({ error: error.message });
    }

    const ids = data.map((x) => x.book_id);
    return res.json(ids);

  } catch (err) {
    console.error("getCollectionBookIds failed:", err);
    return res.status(500).json({ error: "Server error" });
  }
};





/* ============================================
   📝 START READING
============================================ */
export const startReading = async (req, res) => {
  const userId = req.user.id;
  const { book_id } = req.body;

  // Get existing record
  const { data: existing, error: selErr } = await supabase
    .from("user_library")
    .select("progress")
    .eq("user_id", userId)
    .eq("book_id", book_id)
    .maybeSingle();

  if (selErr) return res.status(400).json({ error: selErr.message });

  // Insert if not exists
  if (!existing) {
    const { error } = await supabase
      .from("user_library")
      .insert({ user_id: userId, book_id, progress: 1, last_page: 1 });

    if (error) return res.status(400).json({ error: error.message });

    return res.json({ message: "Started reading", progress: 1 });
  }

  // If already has progress > 1 don't reset to 1
  if (existing.progress > 1) {
    return res.json({ message: "Already started", progress: existing.progress });
  }

  // Update only if progress was 0
  const { error } = await supabase
    .from("user_library")
    .update({ progress: 1 })
    .eq("user_id", userId)
    .eq("book_id", book_id);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Started reading", progress: 1 });
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

