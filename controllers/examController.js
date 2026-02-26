// src/controllers/examController.js
import dayjs from "dayjs";
import { v4 as uuidv4 } from "uuid";
import { supabaseAdmin } from "../utils/pgClient.js";
import fs from "fs";
import path from "path";

const EXAMS_BUCKET = "exam-files";
const SUBMISSION_BUCKET = "submission-files";
const NOTES_BUCKET = "notes-files";

/* -------------------- UNLOCK HELPER -------------------- */
function isUnlocked(exam) {
  if (!exam) return false;

  const now = dayjs();
  const start = exam.start_time ? dayjs(exam.start_time) : null;
  const end = exam.end_time ? dayjs(exam.end_time) : null;

  if (start && start.isAfter(now)) return false;
  if (end && end.isBefore(now)) return false;

  return true;
}

/* -------------------- UPLOAD EXAM FILE -------------------- */
export async function uploadExamFile(req, res) {
  try {
    const examId = Number(req.params.id);
    if (!req.file) return res.status(400).json({ error: "No file uploaded" });

    const filename = `${uuidv4()}-${req.file.originalname.replace(/\s+/g, "_")}`;
    const uploadDir = path.join(process.cwd(), "uploads", "exams");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, req.file.buffer);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${filename}`;

    const { data, error } = await supabaseAdmin
      .from("exams")
      .update({
        file_path: absolutePath, // Keep for deletion later
        file_url: publicUrl,
        file_name: req.file.originalname,
      })
      .eq("id", examId)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, exam: data });
  } catch (err) {
    console.error("uploadExamFile:", err);
    res.status(500).json({ error: err.message });
  }
}

/* -------------------- LIST EXAMS (SHOW ALL) -------------------- */
export async function listExams(req, res) {
  try {
    const { data: exams, error } = await supabaseAdmin
      .from("exams")
      .select("*")
      .order("start_time");

    if (error) throw error;

    const now = dayjs();

    const enriched = await Promise.all(
      (exams || []).map(async (exam) => {
        const unlocked = isUnlocked(exam);

        let view_url = null;
        if (unlocked && (exam.file_url || exam.file_path)) {
          if (exam.file_url) {
             view_url = exam.file_url;
          } else {
             const fileName = path.basename(exam.file_path);
             view_url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${fileName}`;
          }
        }

        return {
          ...exam,
          unlocked,
          view_url, // null for locked exams
        };
      })
    );

    return res.json({ success: true, exams: enriched });
  } catch (err) {
    console.error("listExams:", err);
    res.status(500).json({ error: err.message });
  }
}

/* -------------------- GET EXAM -------------------- */
export async function getExam(req, res) {
  try {
    const id = Number(req.params.id);

    const { data: exam, error } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("id", id)
      .single();

    if (error || !exam) return res.status(404).json({ error: "Not found" });

    const unlocked = isUnlocked(exam);

    let view_url = null;
    if (unlocked && (exam.file_url || exam.file_path)) {
      if (exam.file_url) {
         view_url = exam.file_url;
      } else {
         const fileName = path.basename(exam.file_path);
         view_url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${fileName}`;
      }
    }

    return res.json({
      success: true,
      exam: {
        ...exam,
        unlocked,
        view_url,
      },
    });
  } catch (err) {
    console.error("getExam:", err);
    res.status(500).json({ error: err.message });
  }
}

/* -------------------- ATTEND EXAM -------------------- */
export async function attendExam(req, res) {
  try {
    const examId = Number(req.params.id);
   const userId = req.user?.id;


    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { data: exam, error: examErr } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("id", examId)
      .single();

    if (examErr || !exam) throw examErr;

    if (!isUnlocked(exam)) {
      return res.status(403).json({ error: "Exam not unlocked or closed" });
    }

    let answer_file_path = null;
    let answer_file_url = null;

    if (req.file) {
      const filename = `${uuidv4()}-${req.file.originalname.replace(/\s+/g, "_")}`;
      const uploadDir = path.join(process.cwd(), "uploads", "submissions");
      
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }

      const absolutePath = path.join(uploadDir, filename);
      await fs.promises.writeFile(absolutePath, req.file.buffer);

      answer_file_path = absolutePath;
      answer_file_url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/submissions/${filename}`;
      answer_file_name = req.file.originalname;
    }

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .insert({
        exam_id: examId,
        user_id: userId, // ✅ FIXED
        answer_text: req.body.answer_text || null,
        answer_file_path,
        answer_file_name,
      })
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, submission: data });
  } catch (err) {
    console.error("attendExam:", err);
    res.status(500).json({ error: err.message });
  }
}


/* -------------------- USER: MY SUBMISSIONS -------------------- */
export async function getUserSubmissions(req, res) {
  try {
 const userId = req.user?.id;


    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .select(`
        id,
        exam_id,
        answer_text,
        answer_file_path,
        answer_file_name,
        submitted_at,
        score,
        admin_message,
        exams ( title, file_name )
      `)
      .eq("user_id", userId) // ✅ FIXED
      .order("submitted_at", { ascending: false });

    if (error) throw error;

    const enriched = await Promise.all(
      (data || []).map(async (s) => {
        let fileUrl = null;

        if (s.answer_file_url) {
           fileUrl = s.answer_file_url;
        } else if (s.answer_file_path) {
           const fileName = path.basename(s.answer_file_path);
           fileUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/submissions/${fileName}`;
        }

        return {
          ...s,
          exam_title: s.exams?.title || s.exams?.file_name,
          answer_file_url: fileUrl,
        };
      })
    );

    res.json({ success: true, submissions: enriched });
  } catch (err) {
    console.error("getUserSubmissions:", err);
    res.status(500).json({ error: err.message });
  }
}


/* -------------------- USER SAFE FOLDERS -------------------- */


// src/controllers/examController.js  (only the getFoldersForUser part shown)
export async function getFoldersForUser(req, res) {
  try {
    // 1. Fetch subjects
    const { data: subjects, error: subjectsErr } = await supabaseAdmin
      .from("subjects")
      .select("*")
      .order("label");

    if (subjectsErr) throw subjectsErr;
    if (!subjects) return res.json({ success: true, folders: [] });

    // 2. Fetch notes + exams one time
    const { data: notes } = await supabaseAdmin.from("study_notes").select("*");
    const { data: exams } = await supabaseAdmin.from("exams").select("*");

    // debug: log counts so you can see if exams were fetched
    console.debug("getFoldersForUser: subjects=", (subjects || []).length, "notes=", (notes || []).length, "exams=", (exams || []).length);

    const folders = [];

    // 3. Build folder structure for each subject
    for (const s of subjects) {
      /* NOTES (unchanged) */
      const subjectNotes = await Promise.all(
        (notes || [])
          .filter((n) => n.subject_id === s.id)
          .map(async (n) => {
            let url = n.file_url || null;
            if (!url && n.file_path) {
               const fileName = path.basename(n.file_path);
               url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/study_notes/${fileName}`;
            }

            return {
              id: n.id,
              name: n.file_name,
              url,
              createdAt: n.created_at,
            };
          })
      );

      /* EXAMS (fixed) */
      const subjectExams = await Promise.all(
        (exams || [])
          .filter((e) => e.subject_id === s.id)
          .map(async (e) => {
            // compute a fresh "now" inside the map to avoid any stale timestamp issues
            const now = dayjs();

            const unlocked =
              (!e.start_time || dayjs(e.start_time).isBefore(now)) &&
              (!e.end_time || dayjs(e.end_time).isAfter(now));

            let url = null;

            // Use DB file_url first, or fallback to parsing the path
            if (e.file_url) {
               url = unlocked ? e.file_url : null;
            } else if (e.file_path) {
              if (unlocked) {
                 const fileName = path.basename(e.file_path);
                 url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${fileName}`;
                 console.debug(`Exam url for exam ${e.id}:`, url);
              } else {
                 console.debug(`Exam ${e.id} is locked (start=${e.start_time}, end=${e.end_time})`);
              }
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

      folders.push({
        subjectId: s.id,
        label: s.label,
        notes: subjectNotes,
        exams: subjectExams,
      });
    }

    return res.json({ success: true, folders });
  } catch (err) {
    console.error("getFoldersForUser:", err);
    res.status(500).json({ error: err.message });
  }
}

