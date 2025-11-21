import supabase from "./supabaseClient.js";

/**
 * Log platform activity
 * @param {string} userId - Supabase Auth user ID
 * @param {string} userName - Full name of the user
 * @param {string} action - Human-readable action text
 * @param {string} type - One of: login, subscription, purchase, content, activity
 */
export async function logActivity(userId, userName, action, type = "activity") {
  try {
    await supabase.from("activity_log").insert({
      user_id: userId || null,
      user_name: userName || "Unknown User",
      action,
      type,
      created_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ Failed to log activity:", error.message);
  }
}
