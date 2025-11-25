// controllers/cartController.js
import supabase from "../utils/supabaseClient.js";

/* ------------------------------------------------------------
   GET /api/cart
------------------------------------------------------------ */
export async function getCart(req, res) {
  try {
    const userId = req.user.id;

    const { data: rows, error } = await supabase
      .from("user_cart")
      .select("*")
      .eq("user_id", userId);

    if (error) return res.status(500).json({ error: error.message });

    const enriched = [];

    for (const r of rows ?? []) {
      if (r.book_id) {
        const { data: book } = await supabase
          .from("ebooks")
          .select("id, title, author, price, file_url")
          .eq("id", r.book_id)
          .maybeSingle();

        if (!book) {
          await supabase.from("user_cart").delete().eq("id", r.id);
          continue;
        }

        enriched.push({ ...r, book });
      }

      if (r.note_id) {
        const { data: note } = await supabase
          .from("notes")
          .select("id, title, author, price, file_url")
          .eq("id", r.note_id)
          .maybeSingle();

        if (!note) {
          await supabase.from("user_cart").delete().eq("id", r.id);
          continue;
        }

        enriched.push({ ...r, note });
      }
    }

    return res.json({ items: enriched });

  } catch (err) {
    console.error("Cart GET error:", err);
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
