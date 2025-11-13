import openai from "./openaiClient.js";
import supabase from "../utils/supabaseClient.js";

const CHAT_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
const EMB_MODEL  = process.env.EMBEDDING_MODEL || "text-embedding-3-small";

/* ----------------------------------------------------
 ✅ AUTO TAGGING
---------------------------------------------------- */
export async function aiAutoTags(text, k = 5) {
  const prompt = `Generate up to ${k} short category tags (1–2 words).
Return ONLY in JSON format:
{"tags":["tag1","tag2"]}

CONTENT:
${text}`;

  const rsp = await openai.chat.completions.create({
    model: CHAT_MODEL,
    messages: [{ role: "user", content: prompt }],
    temperature: 0.2,
    response_format: { type: "json_object" }
  });

  const raw = rsp.choices[0].message.content || "{}";

  try {
    const parsed = JSON.parse(raw);
    return parsed.tags?.slice(0, k) || [];
  } catch {
    return [];
  }
}

/* ----------------------------------------------------
 ✅ SUMMARY GENERATION
---------------------------------------------------- */
export async function aiSummary(text) {
  const rsp = await openai.chat.completions.create({
    model: CHAT_MODEL,
    messages: [
      { role: "system", content: "You summarize academic content clearly."},
      { role: "user", content: `Summarize in 150–200 words:\n${text}` }
    ],
    temperature: 0.3
  });

  return rsp.choices[0].message.content?.trim() || "";
}

/* ----------------------------------------------------
 ✅ TEXT EMBEDDINGS
---------------------------------------------------- */
export async function embedText(text) {
  const rsp = await openai.embeddings.create({
    model: EMB_MODEL,
    input: text
  });
  return rsp.data[0].embedding;
}

/* ----------------------------------------------------
 ✅ LOCAL COSINE SIMILARITY
---------------------------------------------------- */
export function cosine(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

/* ----------------------------------------------------
 ✅ SIMPLE MODERATION
---------------------------------------------------- */
export async function moderate(text) {
  const rsp = await openai.moderations.create({
    model: "omni-moderation-latest",
    input: text
  });
  return rsp.results?.[0];
}

/* ----------------------------------------------------
 ✅ PLAGIARISM SUPPORT
 - You must call Supabase RPC: match_ebooks / match_notes
---------------------------------------------------- */
export async function checkPlagiarism(embedding, threshold = 0.90) {
  const { data: ebooks } = await supabase.rpc("match_ebooks", {
    query_embedding: embedding,
    similarity_threshold: threshold,
    match_count: 5
  });

  const { data: notes } = await supabase.rpc("match_notes", {
    query_embedding: embedding,
    similarity_threshold: threshold,
    match_count: 5
  });

  return { ebooks, notes };
}

/* ----------------------------------------------------
 ✅ EMBEDDING FOR SEARCH (semantic search)
---------------------------------------------------- */
export async function semanticSearchEmbed(query) {
  return await embedText(query);
}

/* ----------------------------------------------------
 ✅ AVERAGE EMBEDDINGS (recommendation engine)
---------------------------------------------------- */
export function averageEmbeddings(embeddings = []) {
  if (!embeddings.length) return null;

  const avg = new Array(embeddings[0].length).fill(0);

  embeddings.forEach(vec => {
    vec.forEach((v, i) => {
      avg[i] += v;
    });
  });

  return avg.map(v => v / embeddings.length);
}
