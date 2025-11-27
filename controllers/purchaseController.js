import supabase from "../utils/supabaseClient.js";

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
        if (item.type === "book") {
          const result = await processBookPurchase(userId, item.id);

          // Remove from cart (if exists)
          await supabase
            .from("user_cart")
            .delete()
            .eq("user_id", userId)
            .eq("book_id", item.id);

          results.push({
            type: "book",
            id: item.id,
            purchased: true,
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
            purchased: true,
            alreadyPurchased: !!result?.alreadyPurchased,
          });
        }
      } catch (err) {
        errors.push({ id: item.id, type: item.type, error: err.message });
      }
    }

    if (errors.length > 0) {
      return res.status(207).json({ results, errors });
    }

    return res.json({ success: true, results });
  } catch (err) {
    console.error("unifiedPurchase error:", err);
    return res.status(500).json({ error: "Server error processing purchase" });
  }
};

/* ============================================================
   2️⃣ PROCESS BOOK PURCHASE — USE book_sales TABLE ONLY
=============================================================== */
async function processBookPurchase(userId, bookId) {
  console.log("📌 processBookPurchase START");
  console.log("🟦 USER ID:", userId);
  console.log("🟥 BOOK ID:", bookId);

  if (!bookId) throw new Error("Book ID is required");

  const { data: exists, error: existsError } = await supabase
    .from("book_sales")
    .select("*")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  console.log("🔍 EXISTS RESULT:", exists, "ERROR:", existsError);

  if (exists) {
    console.log("⚠️ Already purchased");
    return { alreadyPurchased: true };
  }

  console.log("📥 Attempting INSERT into book_sales...");

  const { data, error } = await supabase
    .from("book_sales")
    .insert({
      user_id: userId,
      book_id: bookId,
      purchased_at: new Date().toISOString(),
    })
    .select();

  console.log("📤 INSERT RESULT:", data, "ERROR:", error);

  if (error) throw error;

  console.log("✅ INSERT SUCCESS");

  return { success: true };
}

/* ============================================================
   3️⃣ PROCESS NOTE PURCHASE
=============================================================== */
async function processNotePurchase(userId, noteId) {
  if (!noteId) throw new Error("Note ID required");

  const numericId = Number(noteId); // FIXED

  const { data: exists } = await supabase
    .from("notes_purchase")
    .select("id")
    .eq("user_id", userId)
    .eq("note_id", numericId)   // FIXED
    .maybeSingle();

  if (exists) return { alreadyPurchased: true };

  const { error } = await supabase.from("notes_purchase").insert({
    id: crypto.randomUUID(),     // REQUIRED because id = uuid
    user_id: userId,
    note_id: numericId,          // FIXED
    purchased_at: new Date().toISOString(),
  });

  if (error) throw error;

  return { success: true };
}


/* ============================================================
   4️⃣ CHECK PURCHASE STATUS → returns { purchased: true/false }
=============================================================== */
export const checkPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId, noteId } = req.query;

    if (bookId) {
      const { data } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", bookId)
        .maybeSingle();

      return res.json({ purchased: !!data });
    }
if (noteId) {
  const { data } = await supabase
    .from("notes_purchase")
    .select("id")
    .eq("user_id", userId)
    .eq("note_id", Number(noteId))   // FIXED
    .maybeSingle();




      return res.json({ purchased: !!data });
    }

    return res.status(400).json({ error: "Missing bookId or noteId" });
  } catch (err) {
    console.error("checkPurchase error:", err);
    return res.status(500).json({ error: "Error checking purchase" });
  }
};

/* ============================================================
   5️⃣ GET PURCHASED BOOKS (JOIN WITH books TABLE)
=============================================================== */
export const getPurchasedBooks = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data, error } = await supabase
      .from("book_sales")
      .select(`
        *,
        books(*)
      `)
      .eq("user_id", userId);

    if (error) throw error;

    const books = data.map((row) => row.books);

    return res.json(books);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to get purchased books" });
  }
};

/* ============================================================
   6️⃣ GET PURCHASED BOOK IDS → used by Explore page
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

    return res.json(data.map((row) => Number(row.note_id))); // FIXED
  } catch (err) {
    console.error("getPurchasedNoteIds error:", err);
    return res.status(500).json([]);
  }
};

