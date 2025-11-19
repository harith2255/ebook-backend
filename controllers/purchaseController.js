import supabase from "../utils/supabaseClient.js";

// ---------------------------
//  BUY A BOOK
// ---------------------------


// ---------------------------
//  BUY A BOOK + ADD TO LIBRARY
// ---------------------------


export const purchaseBook = async (req, res) => {
  try {
    const { bookId } = req.body;
    const userId = req.user.id;

    if (!bookId) {
      return res.status(400).json({ error: "Book ID required" });
    }

    // 1️⃣ INSERT — book purchase history
    await supabase.from("book_sales").insert([
      {
        user_id: userId,
        book_id: bookId,
        purchased_at: new Date().toISOString(),
      }
    ]);

    // 2️⃣ INSERT — add to user library (PREVENT DUPLICATE)
    const { data: exists } = await supabase
      .from("user_library")
      .select("id")
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .maybeSingle();

    if (!exists) {
      await supabase.from("user_library").insert([
        {
          user_id: userId,
          book_id: bookId,
          progress: 0,
          added_at: new Date().toISOString(),
        }
      ]);
    }

    // 3️⃣ UPDATE book sales count
    const { data: book, error: fetchError } = await supabase
      .from("ebooks")
      .select("sales")
      .eq("id", bookId)
      .single();

    if (fetchError) return res.status(500).json({ error: "Could not fetch current sales" });

    const newSales = (book?.sales || 0) + 1;

    await supabase
      .from("ebooks")
      .update({ sales: newSales })
      .eq("id", bookId);

    res.json({ message: "Book purchased & saved to library" });

  } catch (err) {
    console.error("purchaseBook error:", err);
    res.status(500).json({ error: "Server error purchasing book" });
  }
};





// ---------------------------
//  CHECK IF USER PURCHASED
// ---------------------------
export const checkPurchase = async (req, res) => {
  try {
    const userId = req.user.id;
    const { bookId } = req.query;

    const { data } = await supabase
      .from("book_sales")
      .select("id")
      .eq("user_id", userId)
      .eq("book_id", bookId)
      .maybeSingle();

    res.json({ purchased: !!data });

  } catch (err) {
    console.error("checkPurchase error:", err);
    res.status(500).json({ error: "Error checking purchase" });
  }
};
