// src/controllers/admin/adminExamController.js
import { supabaseAdmin } from "../../utils/supabaseClient.js";
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
    const { data: existing } = await supabaseAdmin
      .from("subjects")
      .select("*")
      .eq("value", value)
      .maybeSingle();

    if (existing) return existing;

    const { data, error } = await supabaseAdmin
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
    const { data, error } = await supabaseAdmin
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

    // Upload to bucket
    const { error: uploadErr } = await supabaseAdmin.storage
      .from(NOTES_BUCKET)
      .upload(path, req.file.buffer, {
        contentType: req.file.mimetype,
      });

    if (uploadErr) throw uploadErr;

    // Insert DB entry
    const { data, error } = await supabaseAdmin
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

    const { data, error } = await supabaseAdmin
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
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                             GET ALL EXAMS (SAFE)                            */
/* -------------------------------------------------------------------------- */
export async function listExams(req, res) {
  try {
    const { data: exams, error } = await supabaseAdmin
      .from("exams")
      .select("*, subjects(label)")
      .order("start_time");

    if (error) throw error;

    const now = dayjs();

    const enriched = await Promise.all(
      (exams || []).map(async (exam) => {
        const unlocked =
          !!exam.start_time &&
          !dayjs(exam.start_time).isAfter(now) &&
          (!exam.end_time || !dayjs(exam.end_time).isBefore(now));

        let view_url = null;

        if (unlocked && exam.file_path) {
          const { data } = await supabaseAdmin.storage
            .from(EXAMS_BUCKET)
            .createSignedUrl(exam.file_path, 300);
          view_url = data?.signedUrl ?? null;
        }

        return { ...exam, unlocked, view_url };
      })
    );

    return res.json({ success: true, exams: enriched });
  } catch (err) {
    console.error("listExams:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* -------------------------------------------------------------------------- */
/*                                ATTEND EXAM                                  */
/* -------------------------------------------------------------------------- */
export async function attendExam(req, res) {
  try {
    const examId = Number(req.params.id);

    const { data: exam } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("id", examId)
      .maybeSingle();

    if (!exam) return res.status(404).json({ error: "Exam not found" });

    const now = dayjs();
    const unlocked =
      !!exam.start_time &&
      !dayjs(exam.start_time).isAfter(now) &&
      (!exam.end_time || !dayjs(exam.end_time).isBefore(now));

    if (!unlocked) return res.status(403).json({ error: "Exam is locked" });

    let answer_file_path = null;

    if (req.file) {
      const filename = `${uuid()}-${req.file.originalname}`;
      const path = `submissions/${filename}`;

      await supabaseAdmin.storage
        .from(SUBMISSION_BUCKET)
        .upload(path, req.file.buffer, {
          contentType: req.file.mimetype,
        });

      answer_file_path = path;
    }

    const { data, error } = await supabaseAdmin
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

    const { data, error } = await supabaseAdmin
      .from("submissions")
      .select(
        `
        id,
        exam_id,
        user_id,
        answer_text,
        answer_file_path,
        answer_file_name,
        submitted_at,
        score,
        admin_message,
        users:user_id (
          email
        )
      `
      )
      .eq("exam_id", examId)
      .order("submitted_at", { ascending: false });

    if (error) throw error;

    const enriched = await Promise.all(
      (data || []).map(async (s) => {
        let url = null;
        if (s.answer_file_path) {
          const { data: signedUrl } = await supabaseAdmin.storage
            .from("submission-files")
            .createSignedUrl(s.answer_file_path, 300);
          url = signedUrl?.signedUrl || null;
        }

        return {
          ...s,
          user_email: s.users?.email || null,
          answer_file_url: url,
          createdAt: s.submitted_at, // frontend expects createdAt
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
/*                               GRADE SUBMISSION                               */
/* -------------------------------------------------------------------------- */
export async function gradeSubmission(req, res) {
  try {
    const submissionId = Number(req.params.id);

    const { data, error } = await supabaseAdmin
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

/* -------------------------------------------------------------------------- */
/*                           GET FOLDERS (ADMIN UI)                            */
/* -------------------------------------------------------------------------- */
// controllers/admin/adminExamController.js

export async function getFolders(req, res) {
  console.log(
    "🔥 getFolders req.user =",
    req.user && {
      id: req.user.id,
      email: req.user.email,
      app_metadata: req.user.app_metadata,
      user_metadata: req.user.user_metadata,
    }
  );

  try {
    // subjects
    const {
      data: subjects,
      error: subErr,
      status: subStatus,
    } = await supabaseAdmin
      .from("subjects")
      .select("*")
      .order("label", { ascending: true });

    console.log("➡ subjects status:", subStatus, "error:", subErr);
    console.log(
      "➡ subjects count:",
      Array.isArray(subjects) ? subjects.length : typeof subjects
    );

    // if no subjects, print environment + client info
    if (!Array.isArray(subjects) || subjects.length === 0) {
      console.warn(
        "⚠ No subjects returned. ENV SUPER_ADMIN_EMAIL:",
        process.env.SUPER_ADMIN_EMAIL
      );
    }

    const now = dayjs();

    const folders = [];

    for (const s of subjects || []) {
      console.log(`\n--- Processing subject: ${s.id} / ${s.label}`);

      // fetch notes for subject
      const {
        data: subjectNotesRaw,
        error: notesErr,
        status: notesStatus,
      } = await supabaseAdmin
        .from("study_notes")
        .select("*")
        .eq("subject_id", s.id)
        .order("created_at", { ascending: false });

      console.log("  notes status:", notesStatus, "error:", notesErr);
      console.log(
        "  notes count:",
        Array.isArray(subjectNotesRaw)
          ? subjectNotesRaw.length
          : typeof subjectNotesRaw
      );

      const subjectNotes = [];
      if (Array.isArray(subjectNotesRaw)) {
        for (const n of subjectNotesRaw) {
          try {
            const { data: storageData, error: storageErr } =
              await supabaseAdmin.storage
                .from(process.env.NOTES_BUCKET || "notes")
                .createSignedUrl(n.file_path, 300);
            if (storageErr)
              console.warn("   storageErr for note", n.id, storageErr);
            subjectNotes.push({
              id: n.id,
              name: n.file_name,
              url: storageData?.signedUrl ?? null,
              createdAt: n.created_at,
            });
          } catch (e) {
            console.error("   exception creating signed url for note", n.id, e);
            subjectNotes.push({
              id: n.id,
              name: n.file_name,
              url: null,
              createdAt: n.created_at,
            });
          }
        }
      }

      // fetch exams for subject
      const {
        data: subjectExamsRaw,
        error: examsErr,
        status: examsStatus,
      } = await supabaseAdmin
        .from("exams")
        .select("*")
        .eq("subject_id", s.id)
        .order("created_at", { ascending: false });

      console.log("  exams status:", examsStatus, "error:", examsErr);
      console.log(
        "  exams count:",
        Array.isArray(subjectExamsRaw)
          ? subjectExamsRaw.length
          : typeof subjectExamsRaw
      );

      const subjectExams = [];
      if (Array.isArray(subjectExamsRaw)) {
        for (const e of subjectExamsRaw) {
          try {
            const unlocked =
              !!e.start_time &&
              !dayjs(e.start_time).isAfter(now) &&
              (!e.end_time || !dayjs(e.end_time).isBefore(now));

            let url = null;
            if (unlocked && e.file_path) {
              const { data: fileData, error: fileErr } =
                await supabaseAdmin.storage
                  .from(process.env.EXAMS_BUCKET || "exams")
                  .createSignedUrl(e.file_path, 300);
              if (fileErr)
                console.warn("   storageErr for exam", e.id, fileErr);
              url = fileData?.signedUrl ?? null;
            }

            const { count } = await supabaseAdmin
              .from("submissions")
              .select("*", { head: true, count: "exact" })
              .eq("exam_id", e.id);

            const { data: graded, error: gradedErr } = await supabaseAdmin
              .from("submissions")
              .select("id")
              .eq("exam_id", e.id)
              .not("score", "is", null);

            if (gradedErr)
              console.warn("   gradedErr for exam", e.id, gradedErr);

            subjectExams.push({
              id: e.id,
              name: e.file_name || e.title,
              url,
              unlocked,
              submissions: count ?? 0,
              graded_count: Array.isArray(graded) ? graded.length : 0,
              createdAt: e.created_at,
            });
          } catch (e) {
            console.error("   exception processing exam", e);
          }
        }
      }

      folders.push({
        id: s.id,
        subject: s.label,
        notes: subjectNotes,
        exams: subjectExams,
      });
    }

    console.log("\n✅ Built folders count:", folders.length);
    return res.json({ success: true, folders });
  } catch (err) {
    console.error("getFolders: CATCH ERROR", err);
    return res.status(500).json({ error: err.message || String(err) });
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
    /* =========== 1. DELETE NOTES =========== */
    const { data: notes } = await supabaseAdmin
      .from("study_notes")
      .select("*")
      .eq("subject_id", subjectId);

    if (notes?.length) {
      const paths = notes.map((n) => n.file_path);
      await supabaseAdmin.storage.from(NOTES_BUCKET).remove(paths);
    }

    await supabaseAdmin
      .from("study_notes")
      .delete()
      .eq("subject_id", subjectId);

    /* =========== 2. DELETE EXAMS =========== */
    const { data: exams } = await supabaseAdmin
      .from("exams")
      .select("*")
      .eq("subject_id", subjectId);

    const examIds = exams?.map((e) => e.id) || [];

    // Delete exam PDFs
    if (exams?.length) {
      const examPaths = exams
        .filter((e) => e.file_path)
        .map((e) => e.file_path);

      if (examPaths.length > 0)
        await supabaseAdmin.storage.from(EXAMS_BUCKET).remove(examPaths);
    }

    /* =========== 3. DELETE SUBMISSIONS =========== */
    const { data: submissions } = await supabaseAdmin
      .from("submissions")
      .select("*")
      .in("exam_id", examIds);

    if (submissions?.length) {
      const submissionPaths = submissions
        .filter((s) => s.answer_file_path)
        .map((s) => s.answer_file_path);

      if (submissionPaths.length > 0)
        await supabaseAdmin.storage
          .from(SUBMISSION_BUCKET)
          .remove(submissionPaths);
    }

    await supabaseAdmin.from("submissions").delete().in("exam_id", examIds);

    /* =========== 4. DELETE EXAMS (DB) =========== */
    await supabaseAdmin.from("exams").delete().eq("subject_id", subjectId);

    /* =========== 5. DELETE SUBJECT =========== */
    await supabaseAdmin.from("subjects").delete().eq("id", subjectId);

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

    const { data, error } = await supabaseAdmin
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
