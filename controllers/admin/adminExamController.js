// src/controllers/admin/adminExamController.js
 import { supabaseAdmin as supabase } from "../../utils/supabaseClient.js";

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
    const { label, value } = req.body;

    if (!label || !value)
      return res.status(400).json({ error: "label & value required" });

    if (!req.file) return res.status(400).json({ error: "PDF file required" });

    const subject = await findOrCreateSubject(label, value);

    const filename = `${uuid()}-${req.file.originalname}`;
    const path = `study_notes/${filename}`;

    const { error: uploadErr } = await supabase.storage
      .from(NOTES_BUCKET)
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
      });

    if (uploadErr) throw uploadErr;

    const { data, error } = await supabase
      .from("study_notes")
      .insert([
        {
          subject_id: subject.id,
          title: req.file.originalname,
          file_name: req.file.originalname,
          file_path: path,
          uploaded_by: req.user.id,
          created_by: req.user.id,
        },
      ])
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, note: data });
  } catch (err) {
    console.error("uploadNote:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                                 CREATE EXAM                                 */
/* -------------------------------------------------------------------------- */
export async function createExam(req, res) {
  try {
    const { label, value, title, description, start_time, end_time } = req.body;

    if (!label || !value || !title)
      return res.status(400).json({ error: "Missing required fields" });

    const subject = await findOrCreateSubject(label, value);

    const { data, error } = await supabase
      .from("exams")
      .insert([
        {
          subject_id: subject.id,
          title,
          description,
          created_by: req.user.id,
          start_time: start_time || null,
          end_time: end_time || null,
        },
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

/* -------------------------------------------------------------------------- */
/*                              UPLOAD EXAM FILE                               */
/* -------------------------------------------------------------------------- */
export async function uploadExamFile(req, res) {
  try {
    const examId = Number(req.params.id);

    if (!req.file) return res.status(400).json({ error: "No file uploaded" });

    const filename = `${uuid()}-${req.file.originalname}`;
    const path = `exams/${filename}`;

    const { error: uploadErr } = await supabase.storage
      .from(EXAMS_BUCKET)
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false,
      });

    if (uploadErr) throw uploadErr;

    const { data, error } = await supabase
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
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                             GET ALL EXAMS (SAFE)                            */
/* -------------------------------------------------------------------------- */
// src/controllers/examController.js (listExams)
// GET ALL EXAMS (SAFE) - patched
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
        if (unlocked && exam.file_path) {
          try {
            const { data: signed } = await supabase.storage
              .from(EXAMS_BUCKET) // <-- use correct constant
              .createSignedUrl(exam.file_path, 300);

            // defensive: supabase might return signedUrl or signed_url
            view_url = signed?.signedUrl ?? signed?.signed_url ?? null;
            console.debug("listExams signed url:", exam.id, view_url);
          } catch (err) {
            console.warn("listExams createSignedUrl error:", err?.message || err, "examId=", exam.id);
            view_url = null;
          }
        }

        return {
          ...exam,
          unlocked,
          view_url, // null for locked or failed signed URLs
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

    if (req.file) {
      const filename = `${uuid()}-${req.file.originalname}`;
      const path = `submissions/${filename}`;

      await supabase.storage
        .from(SUBMISSION_BUCKET)
        .upload(path, req.file.buffer, {
          contentType: req.file.mimetype,
        });

      answer_file_path = path;
    }

    const { data, error } = await supabase
      .from("submissions")
      .insert([
        {
          exam_id: examId,
          user_id: req.user.id,
          answer_text: req.body.answer_text || null,
          answer_file_path,
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
        const { data: userData } = await supabase.auth.admin.getUserById(
          s.user_id
        );

        const email = userData?.user?.email ?? null;

        // signed URL if file exists
        let url = null;
        if (s.answer_file_path) {
          const { data: signed } = await supabase.storage
            .from("submission-files")
            .createSignedUrl(s.answer_file_path, 300);
          url = signed?.signedUrl ?? null;
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
  console.log("🔥 getFolders req.user =", {
    id: req.user?.id,
    email: req.user?.email,
  });

  try {
    const { data: subjects } = await supabase
      .from("subjects")
      .select("*")
      .order("label");

    const now = dayjs();
    const folders = [];

    for (const s of subjects || []) {
      const { data: subjectNotesRaw } = await supabase
        .from("study_notes")
        .select("*")
        .eq("subject_id", s.id)
        .order("created_at", { ascending: false });

      const subjectNotes = [];
      for (const n of subjectNotesRaw || []) {
        const { data: storageData } = await supabase.storage
          .from(NOTES_BUCKET)
          .createSignedUrl(n.file_path, 300);

        subjectNotes.push({
          id: n.id,
          name: n.file_name,
          url: storageData?.signedUrl ?? null,
          createdAt: n.created_at,
        });
      }

      const { data: subjectExamsRaw } = await supabase
        .from("exams")
        .select("*")
        .eq("subject_id", s.id)
        .order("created_at", { ascending: false });

      const subjectExams = [];
for (const e of subjectExamsRaw || []) {

  const unlocked =
    (!e.start_time || dayjs(e.start_time).isBefore(now)) &&
    (!e.end_time || dayjs(e.end_time).isAfter(now));

  // Admin MUST ALWAYS see file
  let url = null;
  if (e.file_path) {
    const { data: signed } = await supabase.storage
      .from(EXAMS_BUCKET)
      .createSignedUrl(e.file_path, 300);

    url = signed?.signedUrl ?? null;
  }

  const { count } = await supabase
    .from("submissions")
    .select("*", { head: true, count: "exact" })
    .eq("exam_id", e.id);

  const { data: graded } = await supabase
    .from("submissions")
    .select("id")
    .eq("exam_id", e.id)
    .not("score", "is", null);

  subjectExams.push({
    id: e.id,
    name: e.file_name || e.title,
    url,
    unlocked,
    submissions: count ?? 0,
    graded_count: graded?.length ?? 0,
    createdAt: e.created_at,
    start_time: e.start_time,
    end_time: e.end_time,
  });
}

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
      await supabase.storage
        .from(NOTES_BUCKET)
        .remove(notes.map((n) => n.file_path));
    }

    await supabase.from("study_notes").delete().eq("subject_id", subjectId);

    const { data: exams } = await supabase
      .from("exams")
      .select("*")
      .eq("subject_id", subjectId);

    if (exams?.length) {
      const examPaths = exams.filter((e) => e.file_path).map((e) => e.file_path);
      if (examPaths.length)
        await supabase.storage.from(EXAMS_BUCKET).remove(examPaths);
    }

    const examIds = exams?.map((e) => e.id) || [];

    const { data: submissions } = await supabase
      .from("submissions")
      .select("*")
      .in("exam_id", examIds);

    if (submissions?.length) {
      const submissionPaths = submissions
        .filter((s) => s.answer_file_path)
        .map((s) => s.answer_file_path);
      if (submissionPaths.length)
        await supabase.storage
          .from(SUBMISSION_BUCKET)
          .remove(submissionPaths);
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
      const filename = `${uuid()}-${file.originalname}`;
      const path = `study_notes/${filename}`;

      await supabase.storage
        .from(NOTES_BUCKET)
        .upload(path, file.buffer, {
          contentType: file.mimetype,
        });

      const { data, error } = await supabase
        .from("study_notes")
        .insert({
          subject_id,
          title: file.originalname,
          file_name: file.originalname,
          file_path: path,
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
      const filename = `${uuid()}-${file.originalname}`;
      const path = `exams/${filename}`;

      await supabase.storage
        .from(EXAMS_BUCKET)
        .upload(path, file.buffer, {
          contentType: file.mimetype,
        });

      const { data, error } = await supabase
        .from("exams")
        .insert({
          subject_id,
          title: file.originalname,
          file_name: file.originalname,
          file_path: path,
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

    // remove from storage
    await supabase.storage
      .from(NOTES_BUCKET)
      .remove([note.file_path]);

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

    // remove from storage
    if (exam.file_path) {
      await supabase.storage
        .from(EXAMS_BUCKET)
        .remove([exam.file_path]);
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
