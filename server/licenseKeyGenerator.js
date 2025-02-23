const crypto = require("crypto");

const validWords = [
  "apple",
  "banana",
  "cherry",
  "dragon",
  "elephant",
  "forest",
  "guitar",
  "hammer",
  "island",
  "jungle",
  "kettle",
  "lemon",
  "mango",
  "needle",
  "orange",
  "pencil",
  "quartz",
  "rabbit",
  "sunset",
  "turtle",
];

const salt = "Pod2024"; // Must match the salt in Swift LicenseManager

function generateLicenseKey() {
  const words = [];
  const usedIndices = new Set();

  while (words.length < 5) {
    const randomIndex = Math.floor(Math.random() * validWords.length);
    if (!usedIndices.has(randomIndex)) {
      usedIndices.add(randomIndex);
      words.push(validWords[randomIndex]);
    }
  }

  // Generate hash for verification (matches Swift implementation)
  const normalizedKey = words.join("");
  const hash = crypto
    .createHash("sha256")
    .update(normalizedKey + salt)
    .digest("hex");

  return {
    words: words,
    hash: hash,
  };
}

// Example usage:
const license = generateLicenseKey();
console.log("License Words:", license.words.join(" "));
console.log("Hash:", license.hash);

module.exports = { generateLicenseKey };
