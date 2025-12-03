import supabase from "../utils/supabaseClient.js";
import crypto from "crypto";

/* ============================================================
   1️⃣  UNIFIED PURCHASE HANDLER (BOOKS + NOTES)
=============================================================== */
export const unifiedPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const { items } = req.body;

    if (!items || !Array.isArray(items)) {
      return res.status(400).json({ error: "Invalid purchase payload" });
    }

    const results = [];
    const errors = [];

    for (const item of items) {
      try {
        if (!item?.id) {
          console.warn("⚠️ Skipping item with no ID:", item);
          errors.push({
            id: null,
            type: item?.type ?? "unknown",
            error: "Missing ID",
          });
          continue;
        }

        if (item.type === "book") {
          const result = await processBookPurchase(userId, item.id);

          // Remove from cart
          await supabase
            .from("user_cart")
            .delete()
            .eq("user_id", userId)
            .eq("book_id", item.id);

          results.push({
            type: "book",
            id: item.id,
            purchased: !result?.skipped,
            alreadyPurchased: !!result?.alreadyPurchased,
          });
        }

        if (item.type === "note") {
          const result = await processNotePurchase(userId, item.id);

          await supabase
            .from("user_cart")
            .delete()
            .eq("user_id", userId)
            .eq("note_id", item.id);

          results.push({
            type: "note",
            id: item.id,
            purchased: !result?.skipped,
            alreadyPurchased: !!result?.alreadyPurchased,
          });
        }
      } catch (err) {
        console.error("Item purchase error:", err);
        errors.push({ id: item.id, type: item.type, error: err.message });
      }
    }

    if (errors.length > 0) {
      return res.status(207).json({ results, errors }); // partial success
    }

    return res.json({ success: true, results });
  } catch (err) {
    console.error("unifiedPurchase error:", err);
    return res.status(500).json({ error: "Server error processing purchase" });
  }
};

/* ============================================================
   2️⃣ PROCESS BOOK PURCHASE — INSERT INTO book_sales
=============================================================== */
async function processBookPurchase(userId, bookId) {

  // skip if purchased earlier
  const { data: exists } = await supabase
    .from("book_sales")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (exists) return { alreadyPurchased: true };

  // 1️⃣ insert into book_sales
  const { error: saleError } = await supabase
    .from("book_sales")
    .insert({
      user_id: userId,
      book_id: bookId,
      purchased_at: new Date().toISOString(),
    });

  if (saleError) throw saleError;

  // 2️⃣ insert into user_library (if not exists)
  const { data: libExists } = await supabase
    .from("user_library")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (!libExists) {
    await supabase
      .from("user_library")
      .insert({
        user_id: userId,
        book_id: bookId,
        progress: 0,
        last_page: 1,
        added_at: new Date().toISOString(),
      });
  }

  // 3️⃣ notify UI
  return { success: true };
}


/* ============================================================
   3️⃣ PROCESS NOTE PURCHASE — INSERT INTO notes_purchase
=============================================================== */
async function processNotePurchase(userId, noteId) {
  if (!noteId) return { skipped: true };

  const numericId = Number(noteId);

  const { data: exists } = await supabase
    .from("notes_purchase")
    .select("id")
    .eq("user_id", userId)
    .eq("note_id", numericId)
    .maybeSingle();

  if (exists) return { alreadyPurchased: true };

  const { error } = await supabase.from("notes_purchase").insert({
    id: crypto.randomUUID(), // UUID required
    user_id: userId,
    note_id: numericId,
    purchased_at: new Date().toISOString(),
  });

  if (error) throw error;

  return { success: true };
}

/* ============================================================
   4️⃣ CHECK PURCHASE STATUS — USED BY BOOK READER
   Returns: { purchased: true/false }
=============================================================== */
export const checkPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId, noteId } = req.query;

    if (!bookId && !noteId) {
      return res.status(400).json({ error: "Missing bookId or noteId" });
    }

    // BOOK
    if (bookId) {
      const { data, error } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", bookId)
        .maybeSingle();

      if (error) {
        console.error("checkPurchase book error:", error);
        return res.status(500).json({ error: "Database error" });
      }

      return res.json({ purchased: !!data });
    }

    // NOTE
    if (noteId) {
      const { data, error } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", Number(noteId))
        .maybeSingle();

      if (error) {
        console.error("checkPurchase note error:", error);
        return res.status(500).json({ error: "Database error" });
      }

      return res.json({ purchased: !!data });
    }
  } catch (err) {
    console.error("checkPurchase error:", err);
    return res.status(500).json({ error: "Error checking purchase" });
  }
};

/* ============================================================
   5️⃣ GET PURCHASED BOOKS WITH DETAILS
=============================================================== */
export const getPurchasedBooks = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("book_sales")
      .select(
        `
        id,
        book_id,
        purchased_at,
        books (*)
      `
      )
      .eq("user_id", userId);

    if (error) throw error;

    const books = data.map((row) => ({
      ...row.books,
      purchased_at: row.purchased_at,
    }));

    return res.json(books);
  } catch (err) {
    console.error("getPurchasedBooks error:", err);
    return res.status(500).json({ error: "Failed to get purchased books" });
  }
};

/* ============================================================
   6️⃣ GET PURCHASED BOOK IDS
=============================================================== */
export const getPurchasedBookIds = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("book_sales")
      .select("book_id")
      .eq("user_id", userId);

    if (error) throw error;

    const ids = data.map((row) => row.book_id);

    return res.json(ids);
  } catch (err) {
    console.error("getPurchasedBookIds error:", err);
    return res.status(500).json([]);
  }
};

/* ============================================================
   7️⃣ GET PURCHASED NOTE IDS
=============================================================== */
export const getPurchasedNoteIds = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", userId);

    if (error) throw error;

    return res.json(data.map((row) => Number(row.note_id)));
  } catch (err) {
    console.error("getPurchasedNoteIds error:", err);
    return res.status(500).json([]);
  }
};
