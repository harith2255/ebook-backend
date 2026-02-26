import supabase from "./pgClient.js";

export async function logActivity(userId, userName, action, type = "activity") {
  try {
    let finalName = userName;

    // Always fetch name from profiles table
    if (userId) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name, first_name, last_name, email")
        .eq("id", userId)
        .single();

      if (profile) {
        finalName =
          profile.full_name ||
          `${profile.first_name || ""} ${profile.last_name || ""}`.trim() ||
          profile.email ||
          finalName;
      }
    }

    finalName = finalName || "Unknown User";

    // Let DB auto-generate timestamp
    await supabase.from("activity_log").insert({
      user_id: userId,
      user_name: finalName,
      action: action || "performed an action",
      type,
    });

  } catch (error) {
    console.error("❌ Failed to log activity:", error.message);
  }
}
