import { supabaseAdmin } from "../../utils/supabaseClient.js";
import { randomUUID } from "crypto";

/* -------------------------
   GET ALL ARTICLES
------------------------- */
export const getArticles = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
    
      .from("current_affairs")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch articles" });
  }
};

/* -------------------------
   CREATE ARTICLE
------------------------- */
export const createArticle = async (req, res) => {
  try {
    const {
      title,
      category,
      content,
      tags,
      importance,
      status,
      date,
      time,
    } = req.body;

    if (!title || !category || !content || !date || !time) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    let imageUrl = null;
    let imagePath = null;

    if (req.file) {
      const fileExt = req.file.originalname.split(".").pop();
      const path = `current-affairs/${new Date().getFullYear()}/${randomUUID()}.${fileExt}`;

      const upload = await supabaseAdmin.storage
        .from("current-affairs")
        .upload(path, req.file.buffer, {
          contentType: req.file.mimetype,
          upsert: false,
        });

      if (upload.error) throw upload.error;

      const { data } = supabaseAdmin.storage
        .from("current-affairs")
        .getPublicUrl(path);

      imageUrl = data.publicUrl;
      imagePath = path;
    }

    const { error } = await supabaseAdmin.from("current_affairs").insert({
      title,
      category,
      content,
      tags,
      importance,
      status,
      article_date: date,
      article_time: time,
      image_url: imageUrl,
      image_path: imagePath,
    });

    if (error) throw error;

    res.json({ message: "Article created successfully" });
  } catch (err) {
    console.error("CREATE ARTICLE ERROR:", err);
    res.status(500).json({ error: "Failed to create article" });
  }
};

/* -------------------------
   UPDATE ARTICLE
------------------------- */
export const updateArticle = async (req, res) => {
  try {
    const { id } = req.params;

    const updateData = {
      ...req.body,
      updated_at: new Date(),
    };

    const { error } = await supabaseAdmin
      .from("current_affairs")
      .update(updateData)
      .eq("id", id);

    if (error) throw error;

    res.json({ message: "Article updated successfully" });
  } catch (err) {
    res.status(500).json({ error: "Failed to update article" });
  }
};

/* -------------------------
   DELETE ARTICLE
------------------------- */
export const deleteArticle = async (req, res) => {
  try {
    const { id } = req.params;

    const { data } = await supabaseAdmin
      .from("current_affairs")
      .select("image_path")
      .eq("id", id)
      .single();

    if (data?.image_path) {
      await supabaseAdmin.storage
        .from("current-affairs")
        .remove([data.image_path]);
    }

    const { error } = await supabaseAdmin
      .from("current_affairs")
      .delete()
      .eq("id", id);

    if (error) throw error;

    res.json({ message: "Article deleted successfully" });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete article" });
  }
};
