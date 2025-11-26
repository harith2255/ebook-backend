// controllers/bookController.js
import supabase from "../utils/supabaseClient.js";

/**
 * ✅ Admin: Add a new book
 * Expected body:
 * {
 *   title: string,
 *   author: string,
 *   description: string,
 *   genre: string,
 *   cover_url: string,
 *   published_year: number,
 *   pages: number,
 *   price: number
 * }
 */
export const addBook = async (req, res) => {
  try {
    const { title, author, description, genre, cover_url, published_year, pages, price } = req.body;

    if (!title || !author || !price) {
      return res.status(400).json({ error: "Title, author, and price are required." });
    }

    const { data, error } = await supabase
      .from("books")
      .insert([{ title, author, description, genre, cover_url, published_year, pages, price }])
      .select();

    if (error) throw error;
    res.status(201).json({ message: "Book added successfully", book: data[0] });
  } catch (err) {
    console.error("Error adding book:", err.message);
    res.status(500).json({ error: "Failed to add book" });
  }
};

/**
 * ✅ Admin: Update a book by ID
 */
export const updateBook = async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    const { data, error } = await supabase.from("books").update(updates).eq("id", id).select();

    if (error) throw error;
    if (!data.length) return res.status(404).json({ error: "Book not found" });

    res.json({ message: "Book updated successfully", book: data[0] });
  } catch (err) {
    console.error("Error updating book:", err.message);
    res.status(500).json({ error: "Failed to update book" });
  }
};

/**
 * ✅ Admin: Delete a book
 */
export const deleteBook = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase.from("books").delete().eq("id", id);

    if (error) throw error;
    res.json({ message: "Book deleted successfully" });
  } catch (err) {
    console.error("Error deleting book:", err.message);
    res.status(500).json({ error: "Failed to delete book" });
  }
};

/**
 * ✅ Public: Get all books
 */
export const getAllBooks = async (req, res) => {
  try {
    const { category, search } = req.query; // optional filters
    let query = supabase.from("books").select("*").order("id", { ascending: false });

    if (category && category !== "All") {
      query = query.eq("category", category);
    }

    if (search) {
      query = query.ilike("title", `%${search}%`);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.json(data);
  } catch (err) {
    console.error("Error fetching books:", err.message);
    res.status(500).json({ error: "Failed to fetch books" });
  }
};


/**
 * ✅ Public: Get a book by ID
 */
export const getBookById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase.from("books").select("*").eq("id", id).single();

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("Error fetching book:", err.message);
    res.status(404).json({ error: "Book not found" });
  }
};

/**
 * ✅ Public: Search books by name
 */
export const searchBooksByName = async (req, res) => {
  try {
    const { name } = req.query;
    if (!name) return res.status(400).json({ error: "Book name query required" });

    const { data, error } = await supabase
      .from("books")
      .select("*")
      .ilike("title", `%${name}%`);

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error("Error searching books:", err.message);
    res.status(500).json({ error: "Failed to search books" });
  }
};

/**
 * ✅ Student: Get books purchased by logged-in user
 */
export const getPurchasedBooks = async (req, res) => {
  try {
    const userId = req.user.id;
    const { data, error } = await supabase
      .from("purchases")
      .select("books(*)")
      .eq("user_id", userId);

    if (error) throw error;

    const books = data.map((item) => item.books);
    res.json(books);
  } catch (err) {
    console.error("Error fetching purchased books:", err.message);
    res.status(500).json({ error: "Failed to fetch purchased books" });
  }
};

/**
 * ✅ Student: Purchase a book
 */
export const purchaseBook = async (req, res) => {
  try {
    const userId = req.user.id;
    const { book_id } = req.body;

    if (!book_id) return res.status(400).json({ error: "Book ID is required" });

    const { data: existing } = await supabase
      .from("purchases")
      .select("*")
      .eq("user_id", userId)
      .eq("book_id", book_id)
      .single();

    if (existing) return res.status(400).json({ error: "Book already purchased" });

    const { data, error } = await supabase
      .from("purchases")
      .insert([{ user_id: userId, book_id }])
      .select();

    if (error) throw error;

    res.status(201).json({ message: "Book purchased successfully", purchase: data[0] });
  } catch (err) {
    console.error("Error purchasing book:", err.message);
    res.status(500).json({ error: "Failed to purchase book" });
  }
};
/**
 * ✅ DRM: Log Book Read Event
 */
export const logBookRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const userName = req.user.full_name || req.user.email;
    const { book_id } = req.body;

    if (!book_id)
      return res.status(400).json({ error: "book_id is required" });

    // Fetch book title
    const { data: book } = await supabase
      .from("books")
      .select("title")
      .eq("id", book_id)
      .single();

    // Insert DRM log
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: userName,
      book_id,
      book_title: book?.title || "Unknown",
      action: "read",
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date()
    });

    return res.json({ message: "Read event logged" });

  } catch (err) {
    console.error("logBookRead error:", err);
    return res.status(500).json({ error: "Failed to log read event" });
  }
};
