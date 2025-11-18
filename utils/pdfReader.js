export default function getPdfPageCount(buffer) {
  try {
    const content = buffer.toString("latin1");

    // Count occurrences of "/Type /Page"
    const matches = content.match(/\/Type\s*\/Page[^s]/g);

    return matches ? matches.length : 0;
  } catch (err) {
    console.error("PDF PAGE COUNT ERROR:", err);
    return 0;
  }
}
