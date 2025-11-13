import supabase from "../utils/supabaseClient.js";

// ✅ Get all books in user's library
export const getUserLibrary = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("user_library")
    .select(`
  id,
  progress,
  added_at,
  books (
    id,
    title,
    author,
    genre,
    cover_url,
    published_year,
    pages,
    price
  )
`)

    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Add a book to library
export const addBookToLibrary = async (req, res) => {
  const userId = req.user.id;
  const { bookId } = req.params;

  const { error } = await supabase
    .from("user_library")
    .insert([{ user_id: userId, book_id: bookId }]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Book added to library" });
};

// ✅ Remove book from library
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

// ✅ Recently added books
export const getRecentBooks = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("user_library")
    .select(`
  id,
  progress,
  added_at,
  books (
    id,
    title,
    author,
    genre,
    cover_url,
    published_year,
    pages,
    price
  )
`)

    .eq("user_id", userId)
    .order("added_at", { ascending: false })
    .limit(5);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Currently reading
export const getCurrentlyReading = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("user_library")
    .select(`
  id,
  progress,
  added_at,
  books (
    id,
    title,
    author,
    genre,
    cover_url,
    published_year,
    pages,
    price
  )
`)

    .eq("user_id", userId)
    .lt("progress", 100)
    .gt("progress", 0);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Completed books
export const getCompletedBooks = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("user_library")
    .select(`
  id,
  progress,
  added_at,
  books (
    id,
    title,
    author,
    genre,
    cover_url,
    published_year,
    pages,
    price
  )
`)

    .eq("user_id", userId)
    .eq("progress", 100);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Search user's library
export const searchLibrary = async (req, res) => {
  try {
    const userId = req.user.id;
    const { query } = req.query;

    // First, get all user library entries with book details
    const { data, error } = await supabase
      .from("user_library")
      .select(`
        id,
        progress,
        added_at,
        books (
          id,
          title,
          author,
          genre,
          cover_url,
          pages,
          price
        )
      `)
      .eq("user_id", userId);

    if (error) throw error;

    // Filter results manually on backend (case-insensitive)
    const filtered = data.filter((entry) =>
      entry.books?.title?.toLowerCase().includes(query.toLowerCase())
    );

    res.json(filtered);
  } catch (err) {
    console.error("Search error:", err.message);
    res.status(500).json({ error: "Failed to search library" });
  }
};

// ====== 📂 COLLECTIONS ======

// ✅ Create a new collection
export const createCollection = async (req, res) => {
  const userId = req.user.id;
  const { name } = req.body;

  const { error } = await supabase
    .from("collections")
    .insert([{ user_id: userId, name }]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Collection created" });
};

// ✅ Get all collections
export const getAllCollections = async (req, res) => {
  const userId = req.user.id;
  const { data, error } = await supabase
    .from("collections")
    .select("*")
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Get books in collection
export const getCollectionBooks = async (req, res) => {
  const { id } = req.params;

  const { data, error } = await supabase
    .from("collection_books")
    .select("*, books(*)")
    .eq("collection_id", id);

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};

// ✅ Add book to collection
export const addBookToCollection = async (req, res) => {
  const { id, bookId } = req.params;

  const { error } = await supabase
    .from("collection_books")
    .insert([{ collection_id: id, book_id: bookId }]);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Book added to collection" });
};

// ✅ Remove book from collection
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

// ✅ Delete entire collection
export const deleteCollection = async (req, res) => {
  const { id } = req.params;

  const { error } = await supabase
    .from("collections")
    .delete()
    .eq("id", id);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ message: "Collection deleted" });
};
