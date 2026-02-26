// controllers/cartController.js
import supabase from "../utils/pgClient.js";

/* ------------------------------------------------------------
   GET /api/cart
------------------------------------------------------------ */
/* ------------------------------------------------------------
   GET /api/cart  (UPDATED)
------------------------------------------------------------ */
export async function getCart(req, res) {
  try {
    const userId = req.user.id;

    // load cart rows
    const { data: rows, error } = await supabase
      .from("user_cart")
      .select("*")
      .eq("user_id", userId);

    if (error) return res.status(500).json({ error: error.message });

    // get purchased books + notes
    const { data: purchasedBooks } = await supabase
      .from("book_sales")
      .select("book_id")
      .eq("user_id", userId);

    const { data: purchasedNotes } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", userId);

    const purchasedBookIds = purchasedBooks.map(p => p.book_id);
    const purchasedNoteIds = purchasedNotes.map(p => p.note_id);

    const enriched = [];

    for (const r of rows ?? []) {
      // 🔥 Auto-remove purchased book
      if (r.book_id && purchasedBookIds.includes(r.book_id)) {
        await supabase.from("user_cart").delete().eq("id", r.id);
        continue;
      }

      // 🔥 Auto-remove purchased note
      if (r.note_id && purchasedNoteIds.includes(r.note_id)) {
        await supabase.from("user_cart").delete().eq("id", r.id);
        continue;
      }

      // fetch actual product
      if (r.book_id) {
        const { data: book } = await supabase
          .from("ebooks")
          .select("id, title, author, price, file_url")
          .eq("id", r.book_id)
          .maybeSingle();

        if (book) enriched.push({ ...r, book });
      }

      if (r.note_id) {
        const { data: note } = await supabase
          .from("notes")
          .select("id, title, author, price, file_url")
          .eq("id", r.note_id)
          .maybeSingle();

        if (note) enriched.push({ ...r, note });
      }
    }

    return res.json({ items: enriched });

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}


/* ------------------------------------------------------------
   POST /api/cart/add
------------------------------------------------------------ */
export async function addToCart(req, res) {
  try {
    const userId = req.user.id;
    const { book_id, note_id } = req.body;

    if ((!book_id && !note_id) || (book_id && note_id)) {
      return res.status(400).json({
        error: "Provide exactly one of book_id or note_id",
      });
    }

    const matchCol = book_id ? { book_id } : { note_id };

    // 🔥 prevent duplicates — user can add only once
    const { data: existing } = await supabase
      .from("user_cart")
      .select("id")
      .eq("user_id", userId)
      .match(matchCol)
      .maybeSingle();

    if (existing) {
      return res.json({ success: true, message: "Item already in cart" });
    }

    const { data, error } = await supabase
      .from("user_cart")
      .insert({
        user_id: userId,
        book_id: book_id || null,
        note_id: note_id || null,
        quantity: 1, // ignored but kept for DB compatibility
      })
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, data });

  } catch (err) {
    console.error("Cart ADD error:", err);
    return res.status(500).json({
      error: err.message || "Failed to add to cart",
    });
  }
}


/* ------------------------------------------------------------
   DELETE /api/cart/:id
------------------------------------------------------------ */
export async function removeCartItem(req, res) {
  try {
    const userId = req.user.id;
    const cartId = req.params.id;

    const { error } = await supabase
      .from("user_cart")
      .delete()
      .eq("id", cartId)
      .eq("user_id", userId);

    if (error) throw error;

    return res.json({ success: true });

  } catch (err) {
    console.error("Cart DELETE error:", err);
    return res.status(500).json({
      error: err.message || "Failed to remove cart item",
    });
  }
}
export async function removePurchasedCartItems(req, res) {
  try {
    const userId = req.user.id;

    // get purchased items
    const { data: purchased } = await supabase
      .from("purchases")
      .select("book_id, note_id")
      .eq("user_id", userId);

    const bookIds = purchased.map(p => p.book_id).filter(Boolean);
    const noteIds = purchased.map(p => p.note_id).filter(Boolean);

    // delete purchased from cart
    await supabase
      .from("user_cart")
      .delete()
      .eq("user_id", userId)
      .in("book_id", bookIds);

    await supabase
      .from("user_cart")
      .delete()
      .eq("user_id", userId)
      .in("note_id", noteIds);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}
