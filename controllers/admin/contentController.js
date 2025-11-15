import supabase from "../../utils/supabaseClient.js";

/* ======================================================
   1. UPLOAD CONTENT
====================================================== */
export const uploadContent = async (req, res) => {
  try {
    const { type, title, author, category, description, price } = req.body;
    const file = req.file;

    if (!file) return res.status(400).json({ error: "File required" });

    // Map content type → bucket/table
    const bucket =
      type === "E-Book" ? "ebooks" :
      type === "Notes" ? "notes" :
      type === "Mock Test" ? "mock_tests" : null;

    if (!bucket) return res.status(400).json({ error: "Invalid content type" });

    const filePath = `${Date.now()}-${file.originalname}`;

    // Upload file
    const { error: uploadErr } = await supabase.storage
      .from(bucket)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (uploadErr) return res.status(400).json({ error: uploadErr.message });

    // Get public URL
    const { data: publicUrl } = supabase.storage
      .from(bucket)
      .getPublicUrl(filePath);

    // Insert DB row
    const table = bucket;

    const { data, error } = await supabase
      .from(table)
      .insert([
        {
          title,
          author,
          category,
          description,
          price,
          file_url: publicUrl.publicUrl,
          pages: 0,
          sales: 0,
          tags: [],
          status: "Published",
          summary: ""
        }
      ])
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    res.status(201).json({ message: "Content uploaded", data });

  } catch (err) {
    console.error("uploadContent error:", err);
    res.status(500).json({ error: "Server error uploading content" });
  }
};

/* ======================================================
   2. LIST CONTENT
====================================================== */
export const listContent = async (req, res) => {
  try {
    const { type, search } = req.query;

    const table =
      type === "books" ? "ebooks" :
      type === "notes" ? "notes" :
      type === "tests" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    let query = supabase.from(table).select("*");

    if (search) {
      query = query.ilike("title", `%${search}%`);
    }

    const { data, error } = await query.order("created_at", {
      ascending: false,
    });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ contents: data });
  } catch (err) {
    console.error("listContent error:", err);
    res.status(500).json({ error: "Server error listing content" });
  }
};

/* ======================================================
   3. DELETE CONTENT
====================================================== */
export const deleteContent = async (req, res) => {
  try {
    const { id, type } = req.params;

    const table =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    const { error } = await supabase.from(table).delete().eq("id", id);
    if (error) return res.status(400).json({ error: error.message });

    res.json({ message: "Content deleted" });
  } catch (err) {
    console.error("deleteContent error:", err);
    res.status(500).json({ error: "Server error deleting content" });
  }
};

/* ======================================================
   4. EDIT CONTENT (with file replacement)
====================================================== */
export const editContent = async (req, res) => {
  try {
    const { id, type } = req.params;
    const updates = req.body;
    const file = req.file;

    // Convert tags "tag1,tag2" → ["tag1", "tag2"]
    if (updates.tags) {
      updates.tags = updates.tags.split(",").map((t) => t.trim());
    }

    const bucket =
      type === "book" ? "ebooks" :
      type === "note" ? "notes" :
      type === "test" ? "mock_tests" : null;

    const table = bucket;

    if (!bucket || !table) {
      return res.status(400).json({ error: `Invalid content type: ${type}` });
    }

    // Get existing file URL
    const { data: existing, error: fetchErr } = await supabase
      .from(table)
      .select("file_url")
      .eq("id", id)
      .single();

    if (fetchErr || !existing) {
      return res.status(404).json({ error: "Content not found" });
    }

    let file_url = existing.file_url;

    // Replace file
    if (file) {
      const oldFilename = existing.file_url.split("/").pop();

      // Delete old file
      await supabase.storage.from(bucket).remove([oldFilename]);

      const newFilePath = `${Date.now()}-${file.originalname}`;

      const { error: uploadErr } = await supabase.storage
        .from(bucket)
        .upload(newFilePath, file.buffer, {
          contentType: file.mimetype,
        });

      if (uploadErr) {
        return res.status(400).json({ error: uploadErr.message });
      }

      const { data: publicUrl } = supabase.storage
        .from(bucket)
        .getPublicUrl(newFilePath);

      file_url = publicUrl.publicUrl;
    }

    // Update row
    const { data, error } = await supabase
      .from(table)
      .update({
        ...updates,
        file_url,
      })
      .eq("id", id)
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    res.json({
      message: "Content updated successfully",
      data,
    });

  } catch (err) {
    console.error("editContent error:", err);
    res.status(500).json({ error: "Server error editing content" });
  }
};
