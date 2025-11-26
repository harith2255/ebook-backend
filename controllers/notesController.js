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
// ✅ Get single note (DRM applied)
export const getNoteById = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: note, error } = await supabase
      .from("notes")
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;

    // DRM is injected by drmCheck middleware
    const drm = req.drm || {};

    res.json({
      note,
      drm: {
        copy_protection: drm.copy_protection,
        watermarking: drm.watermarking,
        screenshot_prevention: drm.screenshot_prevention,
        device_limit: drm.device_limit
      }
    });

  } catch (err) {
    console.error("getNoteById error:", err);
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
// ✅ Track downloads (DRM enforced)
export const incrementDownloads = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Fetch file URL + title
    const { data: note, error: noteErr } = await supabase
      .from("notes")
      .select("file_url, title")
      .eq("id", id)
      .single();

    if (noteErr) throw noteErr;

    // Insert downloaded note entry
    await supabase
      .from("downloaded_notes")
      .insert({
        user_id: userId,
        note_id: Number(id)
      });

    // Log DRM download
    await supabase.from("drm_access_logs").insert({
      user_id: userId,
      user_name: req.user.email,
      book_id: null,
      book_title: null,
      action: "download_note",
      device_info: req.headers["user-agent"],
      ip_address: req.ip,
      created_at: new Date(),
      note_id: Number(id),
      note_title: note.title
    });

    // Return file URL to frontend
    return res.json({
      success: true,
      file_url: note.file_url
    });

  } catch (err) {
    console.error("incrementDownloads error:", err);
    return res.status(400).json({ error: err.message });
  }
};

export const getDownloadedNotes = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("downloaded_notes")
      .select("id, downloaded_at, note:notes(id, title, category, file_url)")
      .eq("user_id", userId);

    if (error) throw error;

    res.json(data);
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

// GET /api/notes/purchase/check?noteId=xxx
export const checkNotePurchase = async (req, res) => {
  try {
    const userId = req.user.id;  // from JWT
    const noteId = req.query.noteId;

    const { data, error } = await supabase
      .from("notes_purchase")
      .select("*")
      .eq("user_id", userId)
      .eq("note_id", noteId)
      .maybeSingle();

    if (error) throw error;

    res.json({ purchased: !!data });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
// POST /api/notes/purchase
export const purchaseNote = async (req, res) => {
  try {
    const userId = req.user.id;
    const { noteId } = req.body;

    console.log("➡ purchaseNote request:", { userId, noteId });

    // First check if already purchased
    const { data: existing, error: existingErr } = await supabase
      .from("notes_purchase")
      .select("*")
      .eq("user_id", userId)
      .eq("note_id", Number(noteId))
      .maybeSingle();

    if (existing) {
      return res.json({
        success: true,
        alreadyPurchased: true,
        message: "Note already purchased"
      });
    }

    const { error } = await supabase
      .from("notes_purchase")
      .insert({
        user_id: userId,
        note_id: Number(noteId),
        purchased_at: new Date(),
      });

    if (error) throw error;

    return res.json({
      success: true,
      alreadyPurchased: false,
      message: "Note purchased successfully"
    });

  } catch (err) {
    console.log("❌ purchaseNote crashed:", err);
    return res.status(500).json({ error: err.message });
  }
};

