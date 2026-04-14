const fs = require("fs");

// Read .env file
const envContent = fs.readFileSync(".env", "utf8");
const env = {};

// Parse .env - handle both KEY=VALUE and multiline values
const lines = envContent.split(/\r?\n/);
for (const line of lines) {
  // Skip comments and empty lines
  if (!line.trim() || line.trim().startsWith("#")) continue;
  
  // Parse KEY=VALUE
  const eqIndex = line.indexOf("=");
  if (eqIndex === -1) continue;
  
  const key = line.substring(0, eqIndex).trim();
  const value = line.substring(eqIndex + 1).trim();
  
  if (key) {
    env[key] = value;
  }
}

// Read template
const template = JSON.parse(fs.readFileSync("env/dart_defines.example.json", "utf8"));

// Populate with real values from .env
for (const key of Object.keys(template)) {
  if (env[key]) {
    template[key] = env[key];
  }
}

// Write release defines file
fs.writeFileSync("env/dart_defines.release.json", JSON.stringify(template, null, 2));
console.log("✅ Successfully created env/dart_defines.release.json");
console.log("Keys populated:", Object.keys(template).filter(k => template[k] && template[k] !== ""));
