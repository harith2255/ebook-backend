import supabase from "../utils/supabaseClient.js";

/* ============================================
   📘 GET ALL BOOKS IN USER LIBRARY
============================================ */
export const getUserLibrary = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    // STEP 1: Purchased books + ebook data
    const { data: purchases, error } = await supabase
      .from("book_sales")
      .select(`
        id,
        book_id,
        purchased_at,
        ebooks!fk_book_sales_book (
  id,
  title,
  author,
  cover_url,
  pages,
  categories (
    id,
    name
  )
)

      `)
      .eq("user_id", userId)
      .order("purchased_at", { ascending: false });

    if (error) throw error;

    if (!purchases || purchases.length === 0) {
      return res.json([]);
    }

    // STEP 2: Progress
    const bookIds = purchases.map(p => p.book_id);

    const { data: libraryRows } = await supabase
      .from("user_library")
      .select("book_id, progress, last_page")
      .in("book_id", bookIds)
      .eq("user_id", userId);

    const libraryMap = new Map();
    (libraryRows || []).forEach(r => libraryMap.set(r.book_id, r));

    // STEP 3: Final normalized response
    const formatted = purchases.map(row => {
      const ebook = row.ebooks || {};
      const lib = libraryMap.get(row.book_id) || {};

      return {
        book_id: row.book_id,

       ebooks: {
  id: ebook.id,
  title: ebook.title,
  author: ebook.author,
  category: ebook.categories?.name ?? null,
  cover_url: ebook.cover_url || "https://placehold.co/300x400",
  pages: ebook.pages || 0,
},


        progress: Number(lib.progress ?? 0),
        added_at: row.purchased_at || null,
      };
    });

    return res.json(formatted);

  } catch (err) {
    console.error("getUserLibrary error:", err);
    return res.status(500).json({ error: "Failed to load library" });
  }
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
      ebooks!fk_user_library_ebooks (
  id,
  title,
  author,
  description,
  cover_url,
  file_url,
  pages,
  price,
  sales,
  categories (
    id,
    name
  )
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
      ebooks!fk_user_library_ebooks (
  id,
  title,
  author,
  description,
  cover_url,
  file_url,
  pages,
  price,
  sales,
  categories (
    id,
    name
  )
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
     ebooks!fk_user_library_ebooks (
  id,
  title,
  author,
  description,
  cover_url,
  file_url,
  pages,
  price,
  sales,
  categories (
    id,
    name
  )
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
       ebooks!fk_user_library_ebooks (
  id,
  title,
  author,
  description,
  cover_url,
  file_url,
  pages,
  price,
  sales,
  categories (
    id,
    name
  )
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

    // 1) Get book_ids from collection
    const { data: rows, error } = await supabase
      .from("collection_books")
      .select("book_id")
      .eq("collection_id", collectionId);

    if (error) throw error;
    if (!rows || rows.length === 0) return res.json([]);

    // 2) Extract book ids
    const ids = rows.map(r => r.book_id);

    // 3) Fetch ebook details
    const { data: books, error: booksErr } = await supabase
      .from("ebooks")
      .select(`
  id,
  title,
  author,
  cover_url,
  pages,
  categories (
    id,
    name
  )
`)

      .in("id", ids);

    if (booksErr) throw booksErr;

    // 4) Format + fallback cover
    const formatted = books.map(b => ({
      id: b.id,
      title: b.title,
      author: b.author,
      category: b.categories?.name ?? null,

      cover_url: b.cover_url || "https://placehold.co/300x400",
      pages: b.pages
    }));

    return res.json(formatted);

  } catch (err) {
    console.error("ERROR getCollectionBooks:", err);
    res.status(500).json({ error: "Failed to fetch collection books" });
  }
};


export const addBookToCollection = async (req, res) => {
  try {
    const collectionId = req.params.id;

    // accept both formats from frontend
    const { book_id, id } = req.body;
    const realBookId = book_id || id;

    if (!realBookId) {
      return res.status(400).json({ error: "book_id is required" });
    }

    // 1) Already exists?
    const { data: existing, error: existingErr } = await supabase
      .from("collection_books")
      .select("id")
      .eq("collection_id", collectionId)
      .eq("book_id", realBookId)
      .maybeSingle();

    if (existingErr) throw existingErr;

    if (existing) {
      return res.json({
        message: "Book already in this collection",
        alreadyAdded: true,
      });
    }

    // 2) Insert
    const { error } = await supabase.from("collection_books").insert({
      collection_id: collectionId,
      book_id: realBookId,
    });

    if (error) throw error;

    return res.json({
      message: "Book added to collection",
      alreadyAdded: false,
    });

  } catch (err) {
    console.error("ADD BOOK TO COLLECTION ERROR:", err);
    return res.status(500).json({ error: "Failed to add book" });
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
    const userId = req.user?.id;
    const { bookId } = req.params;
    let { progress, last_page } = req.body;

    if (!userId) return res.status(401).json({ error: "Unauthorized" });
    if (!bookId) return res.status(400).json({ error: "Missing bookId param" });

    progress = Number(progress);
    last_page = Number(last_page);

    if (isNaN(progress) || isNaN(last_page))
      return res.status(400).json({ error: "Invalid numeric values" });

    const safeProgress = Math.min(100, Math.max(0, Math.round(progress)));
    const now = new Date().toISOString();

    // 1) Try update
    const { data, error } = await supabase
      .from("user_library")
      .update({
        progress: safeProgress,
        last_page,
        completed_at: safeProgress === 100 ? now : null,
      })
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .select("*");

    // DB error
    if (error) return res.status(400).json({ error: error.message });

    // 2) If no row updated → insert new record
    if (!data || data.length === 0) {
      console.warn("⚠️ No matching row — inserting new record");

      const insertPayload = {
        user_id: userId,
        book_id: bookId,
        progress: safeProgress,
        last_page,
        completed_at: safeProgress === 100 ? now : null,
      };

      const { data: newRow, error: insertErr } = await supabase
        .from("user_library")
        .insert([insertPayload])
        .select("*");

      if (insertErr) {
        return res.status(400).json({ error: insertErr.message });
      }

      return res.json({
        success: true,
        data: newRow[0],
      });
    }

    // 3) return updated record
    return res.json({
      success: true,
      data: data[0],
    });

  } catch (err) {
    console.error("💥 SERVER CRASH:", err);
    return res.status(500).json({ error: "Server error updating progress" });
  }
};








export const getCollectionBookIds = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("collection_books")
      .select("book_id");

    if (error) {
      console.error("getCollectionBookIds error:", error);
      return res.json([]);
    }

    const ids = data.map((row) => row.book_id);
    return res.json(ids);

  } catch (err) {
    console.error("getCollectionBookIds failed:", err);
    return res.json([]);
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
  xPct,
  yPct,
  wPct,
  hPct,
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
          x: xPct,
y: yPct,
width: wPct,
height: hPct,

          color,
          text: note,
        },
      ])
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

   res.json({
  id: data.id,
  page: data.page,
  color: data.color,
  text: data.text,
  xPct: data.x,
  yPct: data.y,
  wPct: data.width,
  hPct: data.height,
});

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

export const resetReading = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;

  const { error } = await supabase
    .from("user_library")
    .update({ progress: 0 })
    .eq("user_id", userId)
    .eq("book_id", bookId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Reading reset" });
};
export const removeBookFromAllCollections = async (req, res) => {
  try {
    const { bookId } = req.params;

    const { error } = await supabase
      .from("collection_books")
      .delete()
      .eq("book_id", bookId);

    if (error) throw error;

    res.json({ message: "Book removed from all collections" });

  } catch (err) {
    console.error("removeBookFromAllCollections error:", err);
    return res.status(500).json({ error: "Failed to remove from all collections" });
  }
};
