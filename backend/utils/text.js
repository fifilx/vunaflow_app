/**
 * Converts a name to Title Case regardless of how the user typed it,
 * e.g. "john KAMAU otieno" -> "John Kamau Otieno". Handles hyphenated
 * and apostrophe'd name parts too (e.g. "mary-jane o'brien" -> "Mary-Jane O'Brien").
 */
function toTitleCase(input) {
  if (!input) return input;
  return input
    .trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map((word) =>
      word
        .split('-')
        .map((part) =>
          part
            .split("'")
            .map((seg) => (seg.length ? seg.charAt(0).toUpperCase() + seg.slice(1).toLowerCase() : seg))
            .join("'")
        )
        .join('-')
    )
    .join(' ');
}

module.exports = { toTitleCase };
