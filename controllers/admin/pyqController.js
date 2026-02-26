import fs from "fs";
import path from "path";
import { supabaseAdmin } from "../../utils/pgClient.js";

/* ---------------- HELPERS ---------------- */
const slugify = (text = "") =>
  text.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-");

/* ---------------- UPLOAD PYQ ---------------- */
export const uploadPYQ = async (req, res) => {
  try {
    const { subjectName, year } = req.body;
    const question = req.files?.question?.[0];
    const answer = req.files?.answer?.[0];

    // ✅ CORRECT VALIDATION
    if (!subjectName || !year || (!question && !answer)) {
      return res.status(400).json({
        error: "Either Question Paper or Answer Key is required",
      });
    }

    /* ---------- SUBJECT UPSERT ---------- */
    let { data: subject, error } = await supabaseAdmin
      .from("pyq_subjects")
      .select("*")
      .eq("name", subjectName)
      .single();

    if (!subject) {
      const insert = await supabaseAdmin
        .from("pyq_subjects")
        .insert({ name: subjectName })
        .select()
        .single();

      if (insert.error) throw insert.error;
      subject = insert.data;
    }

    const basePath = path.join("uploads", "pyq", slugify(subjectName), year);
    if (!fs.existsSync(basePath)) {
      fs.mkdirSync(basePath, { recursive: true });
    }

    /* ---------- FILE UPLOAD ---------- */
    const uploadFile = async (file, type) => {
      // Create a URL-safe relative path
      const relPath = `${slugify(subjectName)}/${year}/${type}.pdf`;
      const absolutePath = path.join(basePath, `${type}.pdf`);

      await fs.promises.writeFile(absolutePath, file.buffer);

      const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/pyq/${relPath}`;

      const { error: insertError } = await supabaseAdmin
        .from("pyq_papers")
        .insert({
          subject_id: subject.id,
          year,
          type, // "question" | "answer"
          title: `${year} ${
            type === "question" ? "Question Paper" : "Answer Key"
          }`,
          file_url: publicUrl,
          file_path: absolutePath, // using local fs path now
          file_size: Number((file.size / 1024 / 1024).toFixed(2)),
        });

      if (insertError) throw insertError;
    };

    /* ---------- UPLOAD BASED ON AVAILABILITY ---------- */
    if (question) await uploadFile(question, "question");
    if (answer) await uploadFile(answer, "answer");

    /* ---------- TOUCH SUBJECT ---------- */
    await supabaseAdmin
      .from("pyq_subjects")
      .update({ updated_at: new Date() })
      .eq("id", subject.id);

    return res.json({ message: "PYQ uploaded successfully" });
  } catch (err) {
    console.error("UPLOAD PYQ ERROR:", err);
    return res.status(500).json({
      error: "Upload failed",
      details: err.message,
    });
  }
};

export const getSubjects = async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from("pyq_subjects")
    .select("id,name,updated_at,pyq_papers(count)");

  if (error) return res.status(500).json({ error: error.message });

  return res.json(data);
};

export const getPapersBySubject = async (req, res) => {
  const { subjectId } = req.params;

  const { data, error } = await supabaseAdmin
    .from("pyq_papers")
    .select("*")
    .eq("subject_id", subjectId)
    .order("year", { ascending: false });

  if (error) return res.status(500).json({ error: error.message });

  return res.json(data);
};
export const deletePaper = async (req, res) => {
  const { id } = req.params;

  const { error } = await supabaseAdmin
    .from("pyq_papers")
    .delete()
    .eq("id", id);

  if (error) return res.status(500).json({ error: error.message });

  res.json({ message: "Paper deleted" });
};

export const deleteSubject = async (req, res) => {
  const { id } = req.params;

  const { error } = await supabaseAdmin
    .from("pyq_subjects")
    .delete()
    .eq("id", id);

  if (error) return res.status(500).json({ error: error.message });

  res.json({ message: "Subject deleted" });
};
