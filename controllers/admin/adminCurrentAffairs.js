import { supabaseAdmin } from "../../utils/supabaseClient.js";
import { randomUUID } from "crypto";
import fs from "fs";
import path from "path";

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
      const fileName = `${randomUUID()}.${fileExt}`;
      const yearStr = new Date().getFullYear().toString();
      
      const uploadDir = path.join(process.cwd(), "uploads", "current_affairs", yearStr);
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }

      const absolutePath = path.join(uploadDir, fileName);
      await fs.promises.writeFile(absolutePath, req.file.buffer);

      // We still store a relative-looking path to help with deletion later
      const relativePath = `current_affairs/${yearStr}/${fileName}`;

      imageUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/${relativePath}`;
      imagePath = absolutePath;
    }
const normalizedCategory = category.trim().toLowerCase();

    const { error } = await supabaseAdmin.from("current_affairs").insert({
      title,
     category: normalizedCategory, 
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
  category: req.body.category
    ? req.body.category.trim().toLowerCase()
    : undefined,
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
      try {
        if (fs.existsSync(data.image_path)) {
          await fs.promises.unlink(data.image_path);
        }
      } catch (err) {
        console.error("Failed to delete old image:", err);
      }
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
/* -------------------------
   DELETE CATEGORY (FOLDER)
------------------------- */
export const deleteCategory = async (req, res) => {
  try {
    const { category } = req.params;

    if (!category) {
      return res.status(400).json({ error: "Category required" });
    }

    // 1️⃣ Get image paths for cleanup
    const { data: articles, error: fetchErr } = await supabaseAdmin
      .from("current_affairs")
      .select("image_path")
      .eq("category", category);

    if (fetchErr) throw fetchErr;

    // 2️⃣ Remove images from storage
    const paths = articles
      ?.map(a => a.image_path)
      .filter(Boolean);

    if (paths.length > 0) {
      for (const p of paths) {
        try {
          if (fs.existsSync(p)) {
            await fs.promises.unlink(p);
          }
        } catch (err) {
          console.error("Failed to delete category image:", p, err);
        }
      }
    }

    // 3️⃣ Delete all articles in category
    const { error } = await supabaseAdmin
      .from("current_affairs")
      .delete()
      .eq("category", category);

    if (error) throw error;

    res.json({
      success: true,
      message: `Category "${category}" deleted successfully`,
    });
  } catch (err) {
    console.error("DELETE CATEGORY ERROR:", err);
    res.status(500).json({ error: "Failed to delete category" });
  }
};
