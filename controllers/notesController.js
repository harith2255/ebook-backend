import supabase from "../utils/pgClient.js";
import axios from "axios";
import { PDFDocument } from "pdf-lib"; // needed for preview PDF generation

/* ============================
   GET ALL NOTES (SAFE)
   - No file_url, no sensitive fields
============================= */
export const getAllNotes = async (req, res) => {
  try {
    const { category, search } = req.query;

    let query = supabase
      .from("notes")
      .select(
        `
        id,
        title,
        category,
        author,
        description,
        pages,
        rating,
        downloads,
        price,
        created_at
      `
      )
      .order("created_at", { ascending: false });

    if (category && category !== "All") {
      query = query.eq("category", category);
    }

    if (search) {
      query = query.ilike("title", `%${search}%`);
    }

    const { data, error } = await query;

    if (error) throw error;

    res.json(data || []);
  } catch (err) {
    console.error("getAllNotes error:", err);
    res.status(500).json({ error: "Failed to fetch notes" });
  }
};

/* ============================
   GET NOTE BY ID + PREVIEW
   - Only returns file_url if user purchased or note is free
============================= */
export const getNoteById = async (req, res) => {
  try {
    const noteId = Number(req.params.id);
    if (!noteId || Number.isNaN(noteId)) {
      return res.status(400).json({ error: "Invalid note id" });
    }

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
        cached_preview,
        price,
        pages
      `
      )
      .eq("id", noteId)
      .maybeSingle();

    if (error) throw error;
    if (!note) {
      return res.status(404).json({ error: "Note not found" });
    }

    // Determine preview text
    const previewText = note.cached_preview || note.preview_content || null;

    // Check purchase status
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

    const isFree = note.price === 0 || note.price === "Free";

   if (isFree && userId) {
  await supabase.from("notes_purchase").upsert(
    {
      user_id: userId,
      note_id: noteId,
      purchased_at: new Date().toISOString(),
    },
    { onConflict: "user_id,note_id" }
  );

  isPurchased = true;
}



    // 🔐 Only expose file_url if user can access full note
    const safeNote = {
      ...note,
      file_url: isPurchased || isFree ? note.file_url : null,
    };

    res.json({
      note: safeNote,
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
   - Only if purchased or free
============================= */
export const incrementDownloads = async (req, res) => {
  try {
    const userId = req.user?.id;
    const noteId = Number(req.params.id);

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!noteId || Number.isNaN(noteId)) {
      return res.status(400).json({ error: "Invalid note id" });
    }

    const { data: note, error } = await supabase
      .from("notes")
      .select("file_url, title, price")
      .eq("id", noteId)
      .maybeSingle();

    if (error) throw error;
    if (!note) {
      return res.status(404).json({ error: "Note not found" });
    }

    const isFree = note.price === 0 || note.price === "Free";

    if (!isFree) {
      const { data: purchased, error: purchaseError } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", noteId)
        .maybeSingle();

      if (purchaseError) {
        console.error("Purchase check error:", purchaseError);
        return res
          .status(500)
          .json({ error: "Failed to verify purchase status" });
      }

      if (!purchased) {
        return res
          .status(403)
          .json({ error: "Purchase required to download this note" });
      }
    }

    const insertRes = await supabase.from("downloaded_notes").insert({
      user_id: userId,
      note_id: noteId,
    });

    if (insertRes.error) throw insertRes.error;

    res.json({ success: true, file_url: note.file_url });
  } catch (err) {
    console.error("incrementDownloads error:", err);
    res
      .status(400)
      .json({ error: err.message || "Failed to download note" });
  }
};

/* ============================
   GET USER'S DOWNLOADED NOTES
   - No file_url, just metadata
============================= */
export const getDownloadedNotes = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { data, error } = await supabase
      .from("downloaded_notes")
      .select(
        `
        note:notes(
          id,
          title,
          category
        )
      `
      )
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
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

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
    const userId = req.user?.id;
    const noteId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

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
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { note_id, page, x_pct, y_pct, w_pct, h_pct, color } = req.body;

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
    const userId = req.user?.id;
    const highlightId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

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
    const userId = req.user?.id;
    const noteId = req.params.id;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

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
    const userId = req.user?.id;
    const noteId = req.params.id;
    const { last_page } = req.body;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const payload = {
      user_id: userId,     // REQUIRED
      note_id: noteId,     // REQUIRED
      last_page: Number(last_page),
      updated_at: new Date().toISOString(),
    };

    const { error } = await supabase
      .from("notes_read_history")
      .upsert([payload], { onConflict: "user_id,note_id" });

    if (error) throw error;

    res.json({ success: true, last_page });
  } catch (err) {
    console.error("saveNoteLastPage error:", err);
    res.status(500).json({ error: "Failed to save last page" });
  }
};





/* ============================
   PREVIEW PDF (first 2 pages)
============================= */
/* ============================
   PREVIEW PDF STREAM (FULL PDF)
   - Frontend limits pages
============================= */
export const getNotePreviewPdf = async (req, res) => {
  try {
    const noteId = Number(req.params.id);

    if (!noteId || Number.isNaN(noteId)) {
      return res.status(400).json({ error: "Invalid note id" });
    }

    const { data: note, error: fetchErr } = await supabase
      .from("notes")
      .select("id, title, file_url")
      .eq("id", noteId)
      .maybeSingle();

    if (fetchErr) {
      console.error("[Preview] Fetch error:", fetchErr);
      return res.status(500).json({ error: "DB error" });
    }

    if (!note || !note.file_url) {
      return res.status(404).json({ error: "File not found" });
    }

    // Download full original PDF
    let originalBuffer;
    try {
      const response = await axios.get(note.file_url, {
        responseType: "arraybuffer",
        timeout: 15000,
      });
      originalBuffer = Buffer.from(response.data);
    } catch (err) {
      console.error("[Preview] PDF download failed:", err?.message);
      return res.status(502).json({ error: "Failed to retrieve PDF file" });
    }

    // Load original to get page count
    const originalPdf = await PDFDocument.load(originalBuffer);
    const totalPages = originalPdf.getPageCount();

    // Send PDF + page count header
    res.set({
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="${sanitizeFilename(
        note.title
      )}_preview.pdf"`,
      "Cache-Control": "no-store",
      "X-Total-Pages": String(totalPages),
    });

    return res.send(originalBuffer);

  } catch (err) {
    console.error("[Preview] Unexpected server error:", err);
    return res.status(500).json({
      error: "Server error previewing PDF",
    });
  }
};







/* --------------------------------------------
   Helper: sanitize filename
--------------------------------------------- */
function sanitizeFilename(name) {
  return name.replace(/[<>:"/\\|?*]+/g, "").trim();
}

/* ============================
   Helper: createPreviewPdf
============================= */
async function createPreviewPdf(originalBuffer, pageCount = 2) {
  try {
    const originalPdf = await PDFDocument.load(originalBuffer);
    const totalPages = originalPdf.getPageCount();

    const previewPdf = await PDFDocument.create();

    const pagesToCopy = Math.min(pageCount, totalPages);
    const pageIndices = Array.from({ length: pagesToCopy }, (_, i) => i);

    const copiedPages = await previewPdf.copyPages(originalPdf, pageIndices);
    copiedPages.forEach((p) => previewPdf.addPage(p));

    const pdfBytes = await previewPdf.save();
    return pdfBytes;
  } catch (err) {
    console.error("createPreviewPdf error:", err);
    return null;
  }
}
