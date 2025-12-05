import supabase from "../utils/supabaseClient.js";
import axios from "axios";

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
    console.error("getAllNotes error:", err);
    res.status(500).json({ error: "Failed to fetch notes" });
  }
};

/* ============================
   GET NOTE BY ID + PREVIEW
   (No PDF parsing – uses DB preview)
============================= */
export const getNoteById = async (req, res) => {
  try {
    const noteId = Number(req.params.id);
    const userId = req.user?.id || null;

    const { data: note, error } = await supabase
      .from("notes")
      .select(
        `
        id,
        title,
        category,
        author,
        file_url,
        description,
        preview_content,
        cached_preview
      `
      )
      .eq("id", noteId)
      .maybeSingle();

    if (error) throw error;
    if (!note) {
      return res.status(404).json({ error: "Note not found" });
    }

    // Determine preview text:
    // 1) cached_preview (if you ever fill it)
    // 2) preview_content (pre-filled at upload time)
    // 3) fallback null
    const previewText =
      note.cached_preview ||
      note.preview_content ||
      null;

    // Check purchase status (optional)
    let isPurchased = false;

    if (userId) {
      const { data: purchased, error: purchaseError } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", noteId)
        .maybeSingle();

      if (purchaseError) {
        console.error("Purchase check error:", purchaseError);
      }

      isPurchased = !!purchased;
    }

    res.json({
      note,
      isPurchased,
      preview_content: previewText,
    });
  } catch (err) {
    console.error("getNoteById error:", err);
    res.status(500).json({ error: "Failed to load note" });
  }
};

/* ============================
   DOWNLOAD NOTE (DRM)
============================= */
export const incrementDownloads = async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = Number(req.params.id);

    const { data: note, error } = await supabase
      .from("notes")
      .select("file_url, title")
      .eq("id", noteId)
      .single();

    if (error) throw error;
    if (!note) {
      return res.status(404).json({ error: "Note not found" });
    }

    await supabase.from("downloaded_notes").insert({
      user_id: userId,
      note_id: noteId,
    });

    res.json({ success: true, file_url: note.file_url });
  } catch (err) {
    console.error("incrementDownloads error:", err);
    res.status(400).json({ error: err.message || "Failed to download note" });
  }
};

/* ============================
   GET USER'S DOWNLOADED NOTES
============================= */
export const getDownloadedNotes = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("downloaded_notes")
      .select("note:notes(id, title, category, file_url)")
      .eq("user_id", userId);

    if (error) throw error;

    res.json(data || []);
  } catch (err) {
    console.error("getDownloadedNotes error:", err);
    res.status(500).json({ error: "Failed to get downloaded notes" });
  }
};

/* ============================
   GET ALL PURCHASED NOTES (IDs)
============================= */
export const getPurchasedNotes = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", userId);

    if (error) throw error;

    res.json((data || []).map((n) => n.note_id));
  } catch (err) {
    console.error("getPurchasedNotes error:", err);
    res.status(500).json({ error: "Failed to get purchased notes" });
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
    console.error("getNoteHighlights error:", err);
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
      color,
    } = req.body;

    if (!note_id || !page) {
      return res
        .status(400)
        .json({ error: "note_id and page are required" });
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
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;

    res.json(data);
  } catch (err) {
    console.error("addNoteHighlight error:", err);
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
    console.error("deleteNoteHighlight error:", err);
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
    console.error("getNoteLastPage error:", err);
    res.status(500).json({ error: "Failed to get last page" });
  }
};

/* =====================================================
   SAVE LAST PAGE
===================================================== */
export const saveNoteLastPage = async (req, res) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const { last_page } = req.body;

    if (!last_page) {
      return res.status(400).json({ error: "last_page is required" });
    }

    const { data: exists, error } = await supabase
      .from("notes_read_history")
      .select("id")
      .eq("user_id", userId)
      .eq("note_id", noteId)
      .maybeSingle();

    if (error) throw error;

    if (exists) {
      const { error: updateError } = await supabase
        .from("notes_read_history")
        .update({
          last_page,
          updated_at: new Date().toISOString(),
        })
        .eq("id", exists.id);

      if (updateError) throw updateError;

      return res.json({ success: true, last_page });
    }

    const { error: insertError } = await supabase
      .from("notes_read_history")
      .insert({
        user_id: userId,
        note_id: noteId,
        last_page,
        updated_at: new Date().toISOString(),
      });

    if (insertError) throw insertError;

    res.json({ success: true, last_page });
  } catch (err) {
    console.error("saveNoteLastPage error:", err);
    res.status(500).json({ error: "Failed to save last page" });
  }
};


export const getNotePreviewPdf = async (req, res) => {
  try {
    const noteId = Number(req.params.id);

    // Fetch metadata
    const { data: note, error } = await supabase
      .from("notes")
      .select("id, title, file_url")
      .eq("id", noteId)
      .single();

    if (error || !note) {
      return res.status(404).json({ error: "Note not found" });
    }

    // Download original PDF
    let buffer;
    try {
      const response = await axios.get(note.file_url, {
        responseType: "arraybuffer",
      });
      buffer = Buffer.from(response.data);
    } catch (err) {
      console.error("PDF download failed:", err);
      return res.status(500).json({ error: "Failed to load PDF" });
    }

    // Create 2-page preview
    const previewPdf = await createPreviewPdf(buffer, 2);

    if (!previewPdf) {
      return res.status(500).json({ error: "Failed to create preview" });
    }

    // Send PDF file to browser
    res.set({
      "Content-Type": "application/pdf",
      "Content-Length": previewPdf.length
    });

    return res.send(previewPdf);

  } catch (err) {
    console.error("getNotePreviewPdf error:", err);
    res.status(500).json({ error: "Server error" });
  }
};