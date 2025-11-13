import supabase from "../utils/supabaseClient.js";

// ✅ Get all notes (with filters)
export const getAllNotes = async (req, res) => {
  try {
    const { category, search } = req.query;

    let query = supabase.from("notes").select("*").order("created_at", { ascending: false });

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
    console.error("❌ getAllNotes error:", err.message);
    res.status(500).json({ error: err.message });
  }
};

// ✅ Get single note
export const getNoteById = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase.from("notes").select("*").eq("id", id).single();
    if (error) throw error;
    res.json(data);
  } catch (err) {
    res.status(404).json({ error: "Note not found" });
  }
};

// ✅ Add new note (admin only)
export const addNote = async (req, res) => {
  try {
    const { title, category, author, pages, downloads, rating, price, featured, file_url, preview_content } = req.body;

    const { data, error } = await supabase
      .from("notes")
      .insert([
        {
          title,
          category,
          author,
          pages,
          downloads,
          rating,
          price,
          featured,
          file_url,
          preview_content,
        },
      ])
      .select();

    if (error) throw error;
    res.json({ message: "Note added successfully", note: data[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// ✅ Track downloads
export const incrementDownloads = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: note, error: fetchError } = await supabase
      .from("notes")
      .select("downloads")
      .eq("id", id)
      .single();

    if (fetchError) throw fetchError;

    const { error: updateError } = await supabase
      .from("notes")
      .update({ downloads: note.downloads + 1 })
      .eq("id", id);

    if (updateError) throw updateError;

    res.json({ message: "Download recorded successfully" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Get featured notes
export const getFeaturedNotes = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("notes")
      .select("*")
      .eq("featured", true)
      .order("rating", { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
