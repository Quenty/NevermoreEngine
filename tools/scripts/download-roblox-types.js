var https = require('https');
var fs = require('fs');

function needsDownload(filename) {
  if (!fs.existsSync(filename)) {
    return true;
  }

  // Check age of file
  const stats = fs.statSync(filename);
  const oneDayInMs = 24 * 60 * 60 * 1000;
  const fileAge = Date.now() - stats.mtimeMs;

  if (fileAge > oneDayInMs) {
    return true;
  }

  return false
}

function download(filename, url) {
  if (!needsDownload(filename)) {
    return;
  }

  var file = fs.createWriteStream(filename);
  var request = https.get(url, function(response) {
    response.pipe(file);
  });
}

download('globalTypes.d.lua', 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua');