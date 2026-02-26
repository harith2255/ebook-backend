// src/controllers/admin/adminExamController.js
import { supabaseAdmin as supabase } from "../../utils/pgClient.js";
import fs from "fs";
import path from "path";
import { v4 as uuid } from "uuid";
import dayjs from "dayjs";

/* -------------------------------------------------------------------------- */
/*                                 BUCKET NAMES                                */
/* -------------------------------------------------------------------------- */
const NOTES_BUCKET = "notes-files";
const EXAMS_BUCKET = "exam-files";
const SUBMISSION_BUCKET = "submission-files";

/* -------------------------------------------------------------------------- */
/*                         SUBJECT HELPERS: FIND / CREATE                      */
/* -------------------------------------------------------------------------- */
async function findOrCreateSubject(label, value) {
  try {
    const { data: existing } = await supabase
      .from("subjects")
      .select("*")
      .eq("value", value)
      .maybeSingle();

    if (existing) return existing;

    const { data, error } = await supabase
      .from("subjects")
      .insert({ label, value })
      .select()
      .single();

    if (error) throw error;

    return data;
  } catch (err) {
    console.error("findOrCreateSubject:", err);
    throw err;
  }
}

/* -------------------------------------------------------------------------- */
/*                               LIST SUBJECTS                                 */
/* -------------------------------------------------------------------------- */
export async function listSubjects(req, res) {
  try {
    const { data, error } = await supabase
      .from("subjects")
      .select("*")
      .order("label");

    if (error) throw error;

    return res.json({ success: true, subjects: data });
  } catch (err) {
    console.error("listSubjects:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                                 UPLOAD NOTE                                 */
/* -------------------------------------------------------------------------- */
export async function uploadNote(req, res) {
  try {
    const { subject_id } = req.body;

    if (!subject_id)
      return res.status(400).json({ error: "subject_id required" });

    if (!req.file)
      return res.status(400).json({ error: "PDF file required" });

    // 🔒 reliable lookup
    const { data: subject } = await supabase
      .from("subjects")
      .select("id")
      .eq("id", subject_id)
      .single();

    if (!subject)
      return res.status(400).json({ error: "Invalid subject" });

    const filename = `${uuid()}-${req.file.originalname.replace(/\s+/g, "_")}`;
    const uploadDir = path.join(process.cwd(), "uploads", "study_notes");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, req.file.buffer);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/study_notes/${filename}`;

    const { data: roleCheck } = await supabase.rpc("current_setting", {
      setting_name: "role"
    });
    console.log("DB ROLE:", roleCheck);

    const { data, error } = await supabase
      .from("study_notes")
      .insert({
        subject_id,
        title: req.file.originalname,
        file_name: req.file.originalname,
        file_path: absolutePath, // keeping absolute path for local deletion later
        file_url: publicUrl, // adding a URL for the frontend
        uploaded_by: req.user?.id ?? null,
        created_by: req.user?.id ?? null,
      })
      .select()
      .single();

    if (error) throw error;

    res.json({ success: true, note: data });
  } catch (err) {
    console.error("uploadNote:", err);
    res.status(500).json({ error: err.message });
  }
}


/* -------------------------------------------------------------------------- */
/*                                 CREATE EXAM                                 */
/* -------------------------------------------------------------------------- */
export async function createExam(req, res) {
  try {
    const { subject_id, title, description, start_time, end_time } = req.body;

    if (!subject_id || !title)
      return res.status(400).json({ error: "subject_id & title required" });

    const { data: subject } = await supabase
      .from("subjects")
      .select("id")
      .eq("id", subject_id)
      .single();

    if (!subject)
      return res.status(400).json({ error: "Invalid subject" });

    const { data, error } = await supabase
      .from("exams")
      .insert({
        subject_id,
        title,
        description,
        created_by: req.user?.id ?? null,
        start_time: start_time || null,
        end_time: end_time || null,
      })
      .select()
      .single();

    if (error) throw error;

    res.json({ success: true, exam: data });
  } catch (err) {
    console.error("createExam:", err);
    res.status(500).json({ error: err.message });
  }
}


/* -------------------------------------------------------------------------- */
/*                              UPLOAD EXAM FILE                               */
/* -------------------------------------------------------------------------- */
export async function uploadExamFile(req, res) {
  try {
    const examId = Number(req.params.id);

    if (!req.file) return res.status(400).json({ error: "No file uploaded" });

    const filename = `${uuid()}-${req.file.originalname.replace(/\s+/g, "_")}`;
    const uploadDir = path.join(process.cwd(), "uploads", "exams");
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const absolutePath = path.join(uploadDir, filename);

    await fs.promises.writeFile(absolutePath, req.file.buffer);

    const publicUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${filename}`;

    const { data, error } = await supabase
      .from("exams")
      .update({
        file_path: absolutePath, // keeping absolute path for deletion
        file_url: publicUrl, // adding a URL field
        file_name: req.file.originalname,
      })
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

/* -------------------------------------------------------------------------- */
/*                             GET ALL EXAMS (SAFE)                            */
/* -------------------------------------------------------------------------- */
export async function listExams(req, res) {
  try {
    const { data: exams, error } = await supabase
      .from("exams")
      .select("*")
      .order("start_time");

    if (error) throw error;

    const enriched = await Promise.all(
      (exams || []).map(async (exam) => {
        // fresh time per exam
        const now = dayjs();
        const unlocked =
          (!exam.start_time || dayjs(exam.start_time).isBefore(now)) &&
          (!exam.end_time || dayjs(exam.end_time).isAfter(now));

        let view_url = null;
        if (unlocked && (exam.file_url || exam.file_path)) {
          // If the DB has `file_url`, return it directly instead of creating a signed URL
          if (exam.file_url) {
             view_url = exam.file_url;
          } else {
             // Fallback for locally stored but missing direct field
             const fileName = path.basename(exam.file_path);
             view_url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${fileName}`;
          }
        }

        return {
          ...exam,
          unlocked,
          view_url, // URL to the pdf
        };
      })
    );

    return res.json({ success: true, exams: enriched });
  } catch (err) {
    console.error("listExams:", err);
    res.status(500).json({ error: err.message });
  }
}




/* -------------------------------------------------------------------------- */
/*                                ATTEND EXAM                                  */
/* -------------------------------------------------------------------------- */
export async function attendExam(req, res) {
  try {
    const examId = Number(req.params.id);

    const { data: exam } = await supabase
      .from("exams")
      .select("*")
      .eq("id", examId)
      .maybeSingle();

    if (!exam) return res.status(404).json({ error: "Exam not found" });

    const now = dayjs();
    const unlocked =
      (!exam.start_time || dayjs(exam.start_time).isBefore(now)) &&
      (!exam.end_time   || dayjs(exam.end_time).isAfter(now));

    if (!unlocked) return res.status(403).json({ error: "Exam is locked" });

    let answer_file_path = null;
    let answer_file_url = null;

    if (req.file) {
      const filename = `${uuid()}-${req.file.originalname.replace(/\s+/g, "_")}`;
      const uploadDir = path.join(process.cwd(), "uploads", "submissions");
      
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }

      const absolutePath = path.join(uploadDir, filename);
      await fs.promises.writeFile(absolutePath, req.file.buffer);

      answer_file_path = absolutePath;
      answer_file_url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/submissions/${filename}`;
    }

    const { data, error } = await supabase
      .from("submissions")
      .insert([
        {
          exam_id: examId,
          user_id: req.user.id,
          answer_text: req.body.answer_text || null,
          answer_file_path,
          answer_file_url, // custom field
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

/* -------------------------------------------------------------------------- */
/*                       GET SUBMISSIONS (ADMIN VIEW)                          */
/* -------------------------------------------------------------------------- */
export async function getExamSubmissions(req, res) {
  try {
    const examId = Number(req.params.id);

    // Get submissions WITHOUT join (because FK to auth.users can't auto-join)
    const { data: submissions, error } = await supabase
      .from("submissions")
      .select("*")
      .eq("exam_id", examId)
      .order("submitted_at", { ascending: false });

    if (error) throw error;

    // Fetch user emails manually from auth schema
    const enriched = await Promise.all(
      submissions.map(async (s) => {
        // fetch email
        const { data: profileData } = await supabase
          .from("profiles")
          .select("email")
          .eq("id", s.user_id)
          .maybeSingle();

        const email = profileData?.email ?? null;

        // static URL if file exists
        let url = null;
        if (s.answer_file_url) {
           url = s.answer_file_url;
        } else if (s.answer_file_path) {
           const fileName = path.basename(s.answer_file_path);
           url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/submissions/${fileName}`;
        }

        return {
          ...s,
          user_email: email,
          answer_file_url: url,
          createdAt: s.submitted_at,
        };
      })
    );

    return res.json({ success: true, submissions: enriched });
  } catch (err) {
    console.error("getExamSubmissions:", err);
    return res.status(500).json({ error: err.message });
  }
}


/* -------------------------------------------------------------------------- */
/*                           GET FOLDERS (ADMIN UI)                            */
/* -------------------------------------------------------------------------- */
export async function getFolders(req, res) {
  try {
    const now = dayjs();

    const [{ data: subjects }, { data: notes }, { data: exams }] =
      await Promise.all([
        supabase.from("subjects").select("id,label").order("label"),
        supabase.from("study_notes").select("*"),
        supabase.from("exams").select("*"),
      ]);

    // group notes by subject
    const notesBySubject = {};
    for (const n of notes || []) {
      if (!notesBySubject[n.subject_id]) notesBySubject[n.subject_id] = [];
      notesBySubject[n.subject_id].push(n);
    }

    // group exams by subject
    const examsBySubject = {};
    for (const e of exams || []) {
      if (!examsBySubject[e.subject_id]) examsBySubject[e.subject_id] = [];
      examsBySubject[e.subject_id].push(e);
    }

    // get submission counts in ONE query
    const { data: submissionStats } = await supabase
      .from("submissions")
      .select("exam_id, score")
      .not("exam_id", "is", null);

    const stats = {};
    for (const s of submissionStats || []) {
      if (!stats[s.exam_id]) stats[s.exam_id] = { total: 0, graded: 0 };
      stats[s.exam_id].total++;
      if (s.score !== null) stats[s.exam_id].graded++;
    }

    const folders = [];

    for (const s of subjects || []) {
      const subjectNotes = await Promise.all(
        (notesBySubject[s.id] || []).map(async (n) => {
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

      const subjectExams = await Promise.all(
        (examsBySubject[s.id] || []).map(async (e) => {
          const unlocked =
            (!e.start_time || dayjs(e.start_time).isBefore(now)) &&
            (!e.end_time || dayjs(e.end_time).isAfter(now));

          let url = null;
          if (e.file_url) {
            url = e.file_url;
          } else if (e.file_path) {
            const fileName = path.basename(e.file_path);
            url = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${fileName}`;
          }

          const st = stats[e.id] || { total: 0, graded: 0 };

          return {
            id: e.id,
            name: e.file_name || e.title,
            url,
            unlocked,
            submissions: st.total,
            graded_count: st.graded,
            createdAt: e.created_at,
            start_time: e.start_time,
            end_time: e.end_time,
          };
        })
      );

      folders.push({
        id: s.id,
        subject: s.label,
        notes: subjectNotes,
        exams: subjectExams,
      });
    }

    return res.json({ success: true, folders });
  } catch (err) {
    console.error("getFolders:", err);
    return res.status(500).json({ error: err.message });
  }
}


/* -------------------------------------------------------------------------- */
/*                       UNIFIED UPLOAD (NOTE / EXAM FILE)                     */
/* -------------------------------------------------------------------------- */
export async function uploadUnified(req, res) {
  try {
    const type = (req.body.type || "").toLowerCase();

    if (type === "note") return uploadNote(req, res);
    if (type === "exam") {
      req.params.id = req.body.exam_id;
      return uploadExamFile(req, res);
    }

    return res.status(400).json({ error: "Unknown upload type" });
  } catch (err) {
    console.error("uploadUnified:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                         DELETE SUBJECT (FULL CLEANUP)                       */
/* -------------------------------------------------------------------------- */
export async function deleteSubject(req, res) {
  const subjectId = Number(req.params.id);

  try {
    const { data: notes } = await supabase
      .from("study_notes")
      .select("*")
      .eq("subject_id", subjectId);

    if (notes?.length) {
      for (const n of notes) {
        if (n.file_path && fs.existsSync(n.file_path)) {
          try { await fs.promises.unlink(n.file_path); } catch (e) { console.error("Could not delete note file:", e); }
        }
      }
    }

    await supabase.from("study_notes").delete().eq("subject_id", subjectId);

    const { data: exams } = await supabase
      .from("exams")
      .select("*")
      .eq("subject_id", subjectId);

    if (exams?.length) {
      for (const e of exams) {
        if (e.file_path && fs.existsSync(e.file_path)) {
          try { await fs.promises.unlink(e.file_path); } catch (e) { console.error("Could not delete exam file:", e); }
        }
      }
    }

    const examIds = exams?.map((e) => e.id) || [];

    const { data: submissions } = await supabase
      .from("submissions")
      .select("*")
      .in("exam_id", examIds);

    if (submissions?.length) {
      for (const s of submissions) {
         if (s.answer_file_path && fs.existsSync(s.answer_file_path)) {
            try { await fs.promises.unlink(s.answer_file_path); } catch (e) { console.error("Could not delete submission file:", e); }
         }
      }
    }

    await supabase.from("submissions").delete().in("exam_id", examIds);
    await supabase.from("exams").delete().eq("subject_id", subjectId);
    await supabase.from("subjects").delete().eq("id", subjectId);

    return res.json({
      success: true,
      message: "Subject and all related data deleted successfully.",
    });
  } catch (err) {
    console.error("deleteSubject:", err);
    return res.status(500).json({ error: err.message });
  }
}

export async function updateExam(req, res) {
  try {
    const examId = Number(req.params.id);
    const { title, description, start_time, end_time } = req.body;

    const { data, error } = await supabase
      .from("exams")
      .update({
        title,
        description,
        start_time: start_time || null,
        end_time: end_time || null,
      })
      .eq("id", examId)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, exam: data });
  } catch (err) {
    console.error("updateExam:", err);
    return res.status(500).json({ error: err.message });
  }
}
export async function gradeSubmission(req, res) {
  try {
    const submissionId = Number(req.params.id);

    const { data, error } = await supabase
      .from("submissions")
      .update({
        score: req.body.score ?? null,
        admin_message: req.body.admin_message ?? null,
      })
      .eq("id", submissionId)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, submission: data });
  } catch (err) {
    console.error("gradeSubmission:", err);
    return res.status(500).json({ error: err.message });
  }
}
// POST /api/admin/exams/notes/upload-multiple
export async function uploadMultipleNotes(req, res) {
  try {
    const { subject_id } = req.body;
    if (!subject_id) return res.status(400).json({ error: "subject_id required" });

    if (!req.files || req.files.length === 0)
      return res.status(400).json({ error: "No files uploaded" });

    const files = req.files;
    const uploaded = [];

    for (const file of files) {
      const filename = `${uuid()}-${file.originalname.replace(/\s+/g, "_")}`;
      const uploadDir = path.join(process.cwd(), "uploads", "study_notes");
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }
      const absolutePath = path.join(uploadDir, filename);
      await fs.promises.writeFile(absolutePath, file.buffer);

      const fileUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/study_notes/${filename}`;

      const { data, error } = await supabase
        .from("study_notes")
        .insert({
          subject_id,
          title: file.originalname,
          file_name: file.originalname,
          file_path: absolutePath,
          file_url: fileUrl,
          uploaded_by: req.user?.id ?? null,
          created_by: req.user?.id ?? null,
        })
        .select()
        .single();

      if (error) throw error;

      uploaded.push(data);
    }

    return res.json({ success: true, notes: uploaded });
  } catch (err) {
    console.error("uploadMultipleNotes:", err);
    res.status(500).json({ error: err.message });
  }
}
// POST /api/admin/exams/upload-multiple
export async function uploadMultipleExams(req, res) {
  try {
    const { subject_id } = req.body;
    if (!subject_id) return res.status(400).json({ error: "subject_id required" });

    if (!req.files || req.files.length === 0)
      return res.status(400).json({ error: "No files uploaded" });

    const files = req.files;
    const uploaded = [];

    for (const file of files) {
      const filename = `${uuid()}-${file.originalname.replace(/\s+/g, "_")}`;
      const uploadDir = path.join(process.cwd(), "uploads", "exams");
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
      }
      const absolutePath = path.join(uploadDir, filename);
      await fs.promises.writeFile(absolutePath, file.buffer);

      const fileUrl = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/exams/${filename}`;

      const { data, error } = await supabase
        .from("exams")
        .insert({
          subject_id,
          title: file.originalname,
          file_name: file.originalname,
          file_path: absolutePath,
          file_url: fileUrl,
          created_by: req.user?.id ?? null,
        })
        .select()
        .single();

      if (error) throw error;

      uploaded.push(data);
    }

    return res.json({ success: true, exams: uploaded });
  } catch (err) {
    console.error("uploadMultipleExams:", err);
    res.status(500).json({ error: err.message });
  }
}
// DELETE: /api/admin/exams/notes/:id
export async function deleteNote(req, res) {
  try {
    const noteId = Number(req.params.id);

    // fetch record
    const { data: note, error: err1 } = await supabase
      .from("study_notes")
      .select("*")
      .eq("id", noteId)
      .single();

    if (err1 || !note) return res.status(404).json({ error: "Note not found" });

    // remove from local storage
    if (note.file_path && fs.existsSync(note.file_path)) {
      try {
        await fs.promises.unlink(note.file_path);
      } catch (e) {
        console.warn("Failed to delete note file:", e.message);
      }
    }

    // delete DB record
    await supabase
      .from("study_notes")
      .delete()
      .eq("id", noteId);

    return res.json({ success: true });
  } catch (err) {
    console.error("deleteNote:", err);
    res.status(500).json({ error: err.message });
  }
}
// DELETE: /api/admin/exams/exams/:id
export async function deleteExamFile(req, res) {
  try {
    const examId = Number(req.params.id);

    const { data: exam } = await supabase
      .from("exams")
      .select("*")
      .eq("id", examId)
      .single();

    if (!exam) return res.status(404).json({ error: "Exam not found" });

    // remove from local storage
    if (exam.file_path && fs.existsSync(exam.file_path)) {
      try {
        await fs.promises.unlink(exam.file_path);
      } catch (e) {
        console.warn("Failed to delete exam file:", e.message);
      }
    }

    // delete DB record
    await supabase
      .from("exams")
      .delete()
      .eq("id", examId);

    return res.json({ success: true });
  } catch (err) {
    console.error("deleteExamFile:", err);
    res.status(500).json({ error: err.message });
  }
}
// POST /api/admin/exams/subject
export async function createSubject(req, res) {
  try {
    const { label, value } = req.body;

    if (!label || !value) {
      return res.status(400).json({ error: "label & value required" });
    }

    const subject = await findOrCreateSubject(label, value);

    return res.json({ success: true, subject });
  } catch (err) {
    console.error("createSubject:", err);
    return res.status(500).json({ error: err.message });
  }
}
