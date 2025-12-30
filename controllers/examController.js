// src/controllers/examController.js
import dayjs from "dayjs";
import { v4 as uuidv4 } from "uuid";
import { supabaseAdmin } from "../utils/supabaseClient.js";

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

    const filename = `${uuidv4()}-${req.file.originalname}`;
    const path = `exams/${filename}`;

    const { error: uploadErr } = await supabaseAdmin.storage
      .from(EXAMS_BUCKET)
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false,
      });

    if (uploadErr) throw uploadErr;

    const { data, error } = await supabaseAdmin
      .from("exams")
      .update({
        file_path: path,
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
        if (unlocked && exam.file_path) {
          const { data: signed } = await supabaseAdmin.storage
            .from(EXAMS_BUCKET)
            .createSignedUrl(exam.file_path, 300);

          view_url = signed?.signedUrl ?? null;
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
    if (unlocked && exam.file_path) {
      const { data: signed } = await supabaseAdmin.storage
        .from(EXAMS_BUCKET)
        .createSignedUrl(exam.file_path, 300);

      view_url = signed?.signedUrl ?? null;
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
    let answer_file_name = null;

    if (req.file) {
      const filename = `${uuidv4()}-${req.file.originalname}`;
      const path = `submissions/${filename}`;

      const { error: uploadErr } = await supabaseAdmin.storage
        .from(SUBMISSION_BUCKET)
        .upload(path, req.file.buffer, {
          contentType: req.file.mimetype,
        });

      if (uploadErr) throw uploadErr;

      answer_file_path = path;
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

        if (s.answer_file_path) {
          const { data: signed } = await supabaseAdmin.storage
            .from(SUBMISSION_BUCKET)
            .createSignedUrl(s.answer_file_path, 300);

          fileUrl = signed?.signedUrl ?? null;
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
            let url = null;
            try {
              const { data: signed } = await supabaseAdmin.storage
                .from(NOTES_BUCKET)
                .createSignedUrl(n.file_path, 300);
              url = signed?.signedUrl ?? null;
            } catch (err) {
              console.warn("Note URL error:", err.message);
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

            // generate signed url only if file_path exists; but log result for debugging
            if (e.file_path) {
              try {
                // still only expose URL to users when unlocked
                if (unlocked) {
                  const { data: signed } = await supabaseAdmin.storage
                  .from(EXAMS_BUCKET)

                    .createSignedUrl(e.file_path, 300);
                  url = signed?.signedUrl ?? null;
                  console.debug(`Exam signed url for exam ${e.id}:`, url);
                } else {
                  // keep url null for locked exams (frontend shows countdown or locked UI)
                  console.debug(`Exam ${e.id} is locked (start=${e.start_time}, end=${e.end_time})`);
                }
              } catch (err) {
                // log — do not throw so the folders response still returns
                console.warn("Exam URL error (getFoldersForUser):", err.message, "examId=", e.id);
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

