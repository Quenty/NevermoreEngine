var https = require('https');
var fs = require('fs');

function download(filename, url) {
  if (fs.existsSync(filename)) {
    return;
  }

  var file = fs.createWriteStream(filename);
  var request = https.get(url, function(response) {
    response.pipe(file);
  });
}

download('globalTypes.d.lua', 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua');