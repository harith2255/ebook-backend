// src/controllers/examController.js
import dayjs from "dayjs";
import { v4 as uuidv4 } from "uuid";
import { supabaseAdmin } from "../utils/supabaseClient.js";

const EXAM_BUCKET = "exam-files";
const SUBMISSION_BUCKET = "submission-files";

/* -------------------- UNLOCK HELPER -------------------- */
function isUnlocked(exam) {
  const now = dayjs();
  if (!exam) return false;
  if (exam.start_time && dayjs(exam.start_time).isAfter(now)) return false;
  if (exam.end_time && dayjs(exam.end_time).isBefore(now)) return false;
  return true;
}

/* -------------------- CREATE EXAM (ADMIN) -------------------- */
export async function createExam(req, res) {
  try {
    const { title, description, folder_id, start_time, end_time } = req.body;

    const created_by = req.user?.id || null;

    const { data, error } = await supabaseAdmin
      .from("exams")
      .insert([
        { title, description, folder_id, start_time, end_time, created_by },
      ])
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, exam: data });
  } catch (err) {
    console.error("createExam:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- UPLOAD EXAM FILE -------------------- */
export async function uploadExamFile(req, res) {
  try {
    const examId = Number(req.params.id);

    if (!req.file) return res.status(400).json({ error: "No file uploaded" });

    const filename = `${uuidv4()}-${req.file.originalname}`;
    const path = `exams/${filename}`;

    const { error: uploadErr } = await supabaseAdmin.storage
      .from(EXAM_BUCKET)
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false,
      });

    if (uploadErr) throw uploadErr;

    const { data, error } = await supabaseAdmin
      .from("exams")
      .update({ file_path: path, file_name: req.file.originalname })
      .eq("id", examId)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, exam: data });
  } catch (err) {
    console.error("uploadExamFile:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- LIST EXAMS -------------------- */
export async function listExams(req, res) {
  try {
    const status = req.query.status;

    const { data: exams, error } = await supabaseAdmin
      .from("exams")
      .select("*")
      .order("start_time", { ascending: true });

    if (error) throw error;

    const enriched = await Promise.all(
      exams.map(async (ex) => {
        let signedUrl = null;

        if (ex.file_path && isUnlocked(ex)) {
          const { data: urlData } = await supabaseAdmin.storage
            .from(EXAM_BUCKET)
            .createSignedUrl(ex.file_path, 300);

          signedUrl = urlData?.signedUrl ?? null;
        }

        return { ...ex, unlocked: isUnlocked(ex), view_url: signedUrl };
      })
    );

    let filtered = enriched;

    if (status === "available") filtered = enriched.filter((e) => e.unlocked);
    else if (status === "upcoming")
      filtered = enriched.filter((e) => !e.unlocked && e.start_time);

    return res.json({ success: true, exams: filtered });
  } catch (err) {
    console.error("listExams:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- GET SINGLE EXAM -------------------- */
export async function getExam(req, res) {
  try {
    const id = Number(req.params.id);

    const { data: exam, error } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("id", id)
      .single();

    if (error) return res.status(404).json({ error: "Not found" });

    let signedUrl = null;

    if (exam.file_path && isUnlocked(exam)) {
      const { data: urlData } = await supabaseAdmin.storage
        .from(EXAM_BUCKET)
        .createSignedUrl(exam.file_path, 300);

      signedUrl = urlData?.signedUrl ?? null;
    }

    return res.json({
      success: true,
      exam: {
        ...exam,
        unlocked: isUnlocked(exam),
        view_url: signedUrl,
      },
    });
  } catch (err) {
    console.error("getExam:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- ATTEND EXAM -------------------- */
export async function attendExam(req, res) {
  try {
    const examId = Number(req.params.id);
    const user = req.user;

    if (!user) return res.status(401).json({ error: "Unauthorized" });

    const { data: exam, error: examErr } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("id", examId)
      .single();

    if (examErr) throw examErr;

    if (!isUnlocked(exam))
      return res.status(403).json({ error: "Exam not unlocked or closed" });

    let answer_file_path = null;
    let answer_file_name = null;

    if (req.file) {
      const filename = `${uuidv4()}-${req.file.originalname}`;
      const path = `submissions/${filename}`;

      const { error: uploadErr } = await supabaseAdmin.storage
        .from(SUBMISSION_BUCKET)
        .upload(path, req.file.buffer, {
          contentType: req.file.mimetype,
          upsert: false,
        });

      if (uploadErr) throw uploadErr;

      answer_file_path = path;
      answer_file_name = req.file.originalname;
    }

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .insert([
        {
          exam_id: examId,
          user_id: user.id,
          answer_text: req.body.answer_text || null,
          answer_file_path,
          answer_file_name,
        },
      ])
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, submission: data });
  } catch (err) {
    console.error("attendExam:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- ADMIN: GET ALL SUBMISSIONS -------------------- */
export async function getSubmissions(req, res) {
  try {
    const examId = Number(req.params.id);

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .select("*")
      .eq("exam_id", examId)
      .order("submitted_at", { ascending: false });

    if (error) throw error;

    const enriched = await Promise.all(
      data.map(async (s) => {
        if (!s.answer_file_path) return s;

        const { data: urlData } = await supabaseAdmin.storage
          .from(SUBMISSION_BUCKET)
          .createSignedUrl(s.answer_file_path, 300);

        return { ...s, answer_file_url: urlData?.signedUrl ?? null };
      })
    );

    return res.json({ success: true, submissions: enriched });
  } catch (err) {
    console.error("getSubmissions:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- USER: MY SUBMISSIONS -------------------- */
export async function getUserSubmissions(req, res) {
  try {
    const user = req.user;

    if (!user) return res.status(401).json({ error: "Unauthorized" });

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .select("*")
      .eq("user_id", user.id)
      .order("submitted_at", { ascending: false });

    if (error) throw error;

    const enriched = await Promise.all(
      data.map(async (s) => {
        let url = null;

        if (s.answer_file_path) {
          const { data: signed } = await supabaseAdmin.storage
            .from(SUBMISSION_BUCKET)
            .createSignedUrl(s.answer_file_path, 300);

          url = signed?.signedUrl ?? null;
        }

        return { ...s, answer_file_url: url };
      })
    );

    return res.json({ success: true, submissions: enriched });
  } catch (err) {
    console.error("getUserSubmissions:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------- USER SAFE FOLDERS -------------------- */
export async function getFoldersForUser(req, res) {
  try {
    const { data: subjects } = await supabaseAdmin
      .from("subjects")
      .select("*")
      .order("label");

    const { data: notes } = await supabaseAdmin.from("study_notes").select("*");
    const { data: exams } = await supabaseAdmin.from("exams").select("*");

    const folders = await Promise.all(
      subjects.map(async (s) => {
        /* NOTES */
        const subjectNotes = await Promise.all(
          notes
            .filter((n) => n.subject_id === s.id)
            .map(async (n) => {
              const { data: urlData } = await supabaseAdmin.storage
                .from("notes-files")
                .createSignedUrl(n.file_path, 300);

              return {
                id: n.id,
                name: n.file_name,
                url: urlData?.signedUrl ?? null,
                createdAt: n.created_at,
              };
            })
        );

        /* EXAMS */
        const subjectExams = await Promise.all(
          exams
            .filter((e) => e.subject_id === s.id)
            .map(async (e) => {
              const unlocked = isUnlocked(e);

              let url = null;
              if (unlocked && e.file_path) {
                const { data: urlData } = await supabaseAdmin.storage
                  .from("exam-files")
                  .createSignedUrl(e.file_path, 300);

                url = urlData?.signedUrl ?? null;
              }

              return {
                id: e.id,
                name: e.file_name || e.title,
                url,
                unlocked,
                start_time: e.start_time,
                end_time: e.end_time,
                createdAt: e.created_at,
              };
            })
        );

        return {
          id: s.id,
          subject: s.label,
          notes: subjectNotes,
          exams: subjectExams,
        };
      })
    );

    return res.json({ success: true, folders });
  } catch (err) {
    console.error("getFoldersForUser:", err);
    return res.status(500).json({ error: err.message });
  }
}
