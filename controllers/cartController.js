// controllers/cartController.js
import supabase from "../utils/supabaseClient.js";

/* ------------------------------------------------------------
   GET /api/cart
   Fetch all cart items for the logged-in user
------------------------------------------------------------ */
export async function getCart(req, res) {
  try {
    const userId = req.user.id;

    console.log("STEP 1: Fetch rows...");
    const { data: rows, error: errRows } = await supabase
      .from("user_cart")
      .select("*")
      .eq("user_id", userId);

    if (errRows) {
      console.error("Rows error:", errRows);
      return res.status(500).json({ error: errRows.message });
    }

    console.log("Rows:", rows);

    const enriched = [];

    for (const r of rows ?? []) {
      console.log("Processing row:", r);

      if (r.book_id) {
        console.log("STEP 2: Fetching book...");
        const { data: book, error: errBook } = await supabase
          .from("books")
          .select("*")
          .eq("id", r.book_id)
          .single(); // ⭐ safe option

        if (errBook) {
          console.error("Book error:", errBook);
          return res.status(500).json({ error: errBook.message });
        }

        enriched.push({ ...r, book });
      }

      if (r.note_id) {
        console.log("STEP 3: Fetching note...");
        const { data: note, error: errNote } = await supabase
          .from("notes")
          .select("*")
          .eq("id", r.note_id)
          .single();

        if (errNote) {
          console.error("Note error:", errNote);
          return res.status(500).json({ error: errNote.message });
        }

        enriched.push({ ...r, note });
      }
    }

    console.log("FINAL enriched:", enriched);

   res.json({ items: enriched });

  } catch (err) {
    console.error("Cart GET error:", err);
    return res.status(500).json({ error: err.message });
  }
}


/* ------------------------------------------------------------
   POST /api/cart/add
   Add book or note to cart
------------------------------------------------------------ */
export async function addToCart(req, res) {
  try {
    const userId = req.user.id;
    const { book_id, note_id, quantity = 1 } = req.body;

    if ((!book_id && !note_id) || (book_id && note_id)) {
      return res
        .status(400)
        .json({ error: "Provide exactly one of book_id or note_id" });
    }

    const matchCol = book_id ? { book_id } : { note_id };

    // check if already in cart
    const { data: existing } = await supabase
      .from("user_cart")
      .select("id, quantity")
      .eq("user_id", userId)
      .match(matchCol)
      .maybeSingle();

    if (existing) {
      const newQty = (existing.quantity || 0) + quantity;

      const { data, error } = await supabase
        .from("user_cart")
        .update({ quantity: newQty })
        .eq("id", existing.id)
        .select()
        .single();

      if (error) throw error;
      return res.json({ success: true, data });
    }

    // insert new
    const { data, error } = await supabase
      .from("user_cart")
      .insert({
        user_id: userId,
        book_id: book_id || null,
        note_id: note_id || null,
        quantity,
      })
      .select()
      .single();

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error("Cart ADD error:", err);
    res.status(500).json({ error: err.message || "Failed to add to cart" });
  }
}

/* ------------------------------------------------------------
   PATCH /api/cart/:id
   Update quantity
------------------------------------------------------------ */
export async function updateCartQuantity(req, res) {
  try {
    const userId = req.user.id;
    const cartId = req.params.id;
    const { quantity } = req.body;

    if (!Number.isInteger(quantity) || quantity < 1) {
      return res
        .status(400)
        .json({ error: "Quantity must be an integer >= 1" });
    }

    const { data, error } = await supabase
      .from("user_cart")
      .update({ quantity })
      .eq("id", cartId)
      .eq("user_id", userId)
      .select()
      .single();

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    console.error("Cart PATCH error:", err);
    res.status(500).json({ error: err.message || "Failed to update cart" });
  }
}

/* ------------------------------------------------------------
   DELETE /api/cart/:id
   Remove item
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

    res.json({ success: true });
  } catch (err) {
    console.error("Cart DELETE error:", err);
    res.status(500).json({ error: err.message || "Failed to remove cart item" });
  }
}
