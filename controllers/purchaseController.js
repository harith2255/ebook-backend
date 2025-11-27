import supabase from "../utils/supabaseClient.js";

/* ============================
   UNIFIED PURCHASE HANDLER
============================= */
export const unifiedPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const { items, type } = req.body;

    if (!items && !type) {
      return res.status(400).json({ error: "Purchase data required" });
    }

    const purchaseItems = items || [
      type === "book"
        ? { type: "book", id: req.body.bookId || req.body.book_id }
        : { type: "note", id: req.body.noteId || req.body.note_id }
    ];

    const results = [];
    const errors = [];

    for (const item of purchaseItems) {
      try {
        if (item.type === "book") {
          await processBookPurchase(userId, item.id);
          results.push({ type: "book", id: item.id, success: true, isPurchased: true });
        } else if (item.type === "note") {
          await processNotePurchase(userId, item.id);
          results.push({ type: "note", id: item.id, success: true, isPurchased: true });
        }
      } catch (err) {
        errors.push({ type: item.type, id: item.id, error: err.message });
      }
    }

    if (errors.length > 0) {
      return res.status(207).json({
        success: false,
        message: "Some purchases failed",
        results,
        errors
      });
    }

    res.json({ success: true, results });

  } catch (err) {
    console.error("unifiedPurchase error:", err);
    res.status(500).json({ error: "Server error processing purchase" });
  }
};

/* ============================
   PROCESS BOOK PURCHASE
============================= */
async function processBookPurchase(userId, bookId) {
  if (!bookId) throw new Error("Book ID is required");

  const { data: exists } = await supabase
    .from("book_sales")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (exists) return { alreadyPurchased: true };

  const { error } = await supabase
    .from("book_sales")
    .insert({
      user_id: userId,
      book_id: bookId,
      purchased_at: new Date().toISOString()
    });

  if (error) throw error;

  return { success: true };
}

/* ============================
   PROCESS NOTE PURCHASE
============================= */
async function processNotePurchase(userId, noteId) {
  if (!noteId) throw new Error("Note ID is required");

  const { data: exists } = await supabase
    .from("notes_purchase")
    .select("id")
    .eq("user_id", userId)
    .eq("note_id", noteId)
    .maybeSingle();

  if (exists) return { alreadyPurchased: true };

  const { error } = await supabase
    .from("notes_purchase")
    .insert({
      user_id: userId,
      note_id: noteId,
      purchased_at: new Date().toISOString()
    });

  if (error) throw error;

  return { success: true };
}

/* ============================
   LEGACY NOTE PURCHASE
============================= */
export const purchaseNote = async (req, res) => {
  try {
    const userId = req.user.id;
    const effectiveNoteId = req.body.noteId || req.body.note_id;

    if (!effectiveNoteId) {
      return res.status(400).json({ error: "Note ID required" });
    }

    const { data: exists } = await supabase
      .from("notes_purchase")
      .select("id")
      .eq("user_id", userId)
      .eq("note_id", effectiveNoteId)
      .maybeSingle();

    if (exists) {
      return res.json({
        success: true,
        isPurchased: true,
        message: "Note already purchased"
      });
    }

    await supabase.from("notes_purchase").insert({
      user_id: userId,
      note_id: effectiveNoteId,
      purchased_at: new Date().toISOString()
    });

    res.json({
      success: true,
      isPurchased: true,
      message: "Note purchased successfully"
    });

  } catch (err) {
    console.error("purchaseNote error:", err);
    res.status(500).json({ error: "Server error purchasing note" });
  }
};

/* ============================
   CHECK PURCHASE STATUS
============================= */
export const checkPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const effectiveNoteId = req.query.noteId || req.query.note_id;
    const effectiveBookId = req.query.bookId || req.query.book_id;

    if (req.query.type === "note" || effectiveNoteId) {
      const { data } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", effectiveNoteId)
        .maybeSingle();

      return res.json({ purchased: !!data });
    }

    if (req.query.type === "book" || effectiveBookId) {
      const { data } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", effectiveBookId)
        .maybeSingle();

      return res.json({ purchased: !!data });
    }

    res.status(400).json({ error: "bookId or noteId required" });

  } catch (err) {
    console.error("checkPurchase error:", err);
    res.status(500).json({ error: "Error checking purchase" });
  }
};

/* ============================
   GET PURCHASED BOOKS
============================= */
export const getPurchasedBooks = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("book_sales")
      .select("ebooks(*)")
      .eq("user_id", req.user.id);

    if (error) throw error;

    res.json(data.map(item => item.ebooks));

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ============================
   GET PURCHASED BOOK IDS
============================= */
export const getPurchasedBookIds = async (req, res) => {
  try {
    const { data } = await supabase
      .from("book_sales")
      .select("book_id")
      .eq("user_id", req.user.id);

    res.json(data.map(b => b.book_id));

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

/* ============================
   GET PURCHASED NOTE IDS
============================= */
export const getPurchasedNoteIds = async (req, res) => {
  try {
    const { data } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", req.user.id);

    res.json(data.map(n => n.note_id));

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
