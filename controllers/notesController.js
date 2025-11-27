import supabase from "../utils/supabaseClient.js";

/* ============================
   GET ALL NOTES
============================= */
export const getAllNotes = async (req, res) => {
  try {
    const { category, search } = req.query;

    let query = supabase
      .from("notes")
      .select("*")
      .order("created_at", { ascending: false });

    if (category && category !== "All") query = query.eq("category", category);
    if (search) query = query.ilike("title", `%${search}%`);

    const { data, error } = await query;

    if (error) throw error;

    res.json(data);
  } catch (err) {
    console.error("getAllNotes error:", err);
    res.status(500).json({ error: "Failed to fetch notes" });
  }
};


/* ============================
   GET NOTE BY ID + DRM + PURCHASE STATUS
============================= */
export const getNoteById = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Check if purchased
    const { data: purchased } = await supabase
      .from("notes_purchase")
      .select("id")
      .eq("user_id", userId)
      .eq("note_id", id)
      .maybeSingle();

    // Fetch note
    const { data: note, error } = await supabase
      .from("notes")
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;

    const drm = req.drm || {};

    res.json({
      note,
      isPurchased: !!purchased,
      drm: {
        copy_protection: drm.copy_protection,
        watermarking: drm.watermarking,
        screenshot_prevention: drm.screenshot_prevention,
        device_limit: drm.device_limit
      }
    });
  } catch (err) {
    console.error("getNoteById error:", err.message);
    res.status(404).json({ error: "Note not found" });
  }
};

/* ============================
   DOWNLOAD NOTE (DRM)
============================= */
export const incrementDownloads = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const { data: note } = await supabase
      .from("notes")
      .select("file_url, title")
      .eq("id", id)
      .single();

    await supabase.from("downloaded_notes").insert({
      user_id: userId,
      note_id: Number(id)
    });

    res.json({ success: true, file_url: note.file_url });
  } catch (err) {
    console.error("incrementDownloads error:", err);
    res.status(400).json({ error: err.message });
  }
};

/* ============================
   GET USER'S DOWNLOADED NOTES
============================= */
export const getDownloadedNotes = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data } = await supabase
      .from("downloaded_notes")
      .select("note:notes(id, title, category, file_url)")
      .eq("user_id", userId);

    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ============================
   GET ALL PURCHASED NOTES (IDs)
============================= */
export const getPurchasedNotes = async (req, res) => {
  try {
    const userId = req.user.id;

    // FIXED: changed from user_notes → notes_purchase
    const { data, error } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", userId);

    if (error) throw error;

    res.json(data.map(n => n.note_id));
  } catch (err) {
    console.error("getPurchasedNotes error:", err.message);
    res.status(500).json({ error: err.message });
  }
};
/* =====================================================
   GET HIGHLIGHTS FOR A NOTE (per user)
===================================================== */
export const getNoteHighlights = async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const { data, error } = await supabase
      .from("notes_highlights")
      .select("*")
      .eq("user_id", userId)
      .eq("note_id", noteId)
      .order("created_at", { ascending: true });

    if (error) throw error;

    res.json(data || []);
  } catch (err) {
    console.error("getNoteHighlights error:", err.message);
    res.status(500).json({ error: "Failed to load highlights" });
  }
};

/* =====================================================
   ADD A NEW HIGHLIGHT
===================================================== */
export const addNoteHighlight = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      note_id,
      page,
      x_pct,
      y_pct,
      w_pct,
      h_pct,
      color
    } = req.body;

    if (!note_id || !page) {
      return res.status(400).json({ error: "note_id and page are required" });
    }

    const { data, error } = await supabase
      .from("notes_highlights")
      .insert({
        user_id: userId,
        note_id,
        page,
        x_pct,
        y_pct,
        w_pct,
        h_pct,
        color: color || "rgba(255,255,0,0.35)",
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) throw error;

    res.json(data);
  } catch (err) {
    console.error("addNoteHighlight error:", err.message);
    res.status(500).json({ error: "Failed to add highlight" });
  }
};

/* =====================================================
   DELETE HIGHLIGHT
===================================================== */
export const deleteNoteHighlight = async (req, res) => {
  try {
    const userId = req.user.id;
    const highlightId = req.params.id;

    const { error } = await supabase
      .from("notes_highlights")
      .delete()
      .eq("id", highlightId)
      .eq("user_id", userId);

    if (error) throw error;

    res.json({ success: true });
  } catch (err) {
    console.error("deleteNoteHighlight error:", err.message);
    res.status(500).json({ error: "Failed to delete highlight" });
  }
};

/* =====================================================
   GET LAST PAGE (per user)
===================================================== */
export const getNoteLastPage = async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const { data, error } = await supabase
      .from("notes_read_history")
      .select("last_page")
      .eq("user_id", userId)
      .eq("note_id", noteId)
      .maybeSingle();

    if (error) throw error;

    res.json(data || { last_page: 1 });
  } catch (err) {
    console.error("getNoteLastPage error:", err.message);
    res.status(500).json({ error: "Failed to get last page" });
  }
};

/* =====================================================
   SAVE LAST PAGE (auto-save every 500ms)
===================================================== */
export const saveNoteLastPage = async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const { last_page } = req.body;

    if (!last_page) {
      return res.status(400).json({ error: "last_page is required" });
    }

    // Check if exists
    const { data: exists } = await supabase
      .from("notes_read_history")
      .select("id")
      .eq("user_id", userId)
      .eq("note_id", noteId)
      .maybeSingle();

    if (exists) {
      // UPDATE
      const { error } = await supabase
        .from("notes_read_history")
        .update({
          last_page,
          updated_at: new Date().toISOString()
        })
        .eq("id", exists.id);

      if (error) throw error;

      return res.json({ success: true, last_page });
    }

    // INSERT NEW
    const { error } = await supabase
      .from("notes_read_history")
      .insert({
        user_id: userId,
        note_id: noteId,
        last_page,
        updated_at: new Date().toISOString()
      });

    if (error) throw error;

    res.json({ success: true, last_page });
  } catch (err) {
    console.error("saveNoteLastPage error:", err.message);
    res.status(500).json({ error: "Failed to save last page" });
  }
};