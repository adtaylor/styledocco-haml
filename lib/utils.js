
/*
General purpose utitily functions
*/

(function() {
  var path;

  path = require('path');

  exports.trimNewLines = function(str) {
    return str.replace(/^\n*/, '').replace(/\n*$/, '');
  };

  exports.makeDestination = function(file) {
    return path.join(path.dirname(file), path.basename(file, path.extname(file)) + '.html');
  };

  exports.buildRootPath = function(str) {
    var root;
    if (path.dirname(str) === '.') {
      root = path.dirname(str);
    } else {
      root = path.dirname(str).replace(/[^\/]+/g, '..');
    }
    if (root.slice(-1) !== '/') root += '/';
    return root;
  };

  exports.splitFixtures = function(haml) {
    var code;
    code = haml.split('FIXTURE:');
    return {
      json: code[1] != null ? JSON.parse(code[1]) : {},
      haml: code[0]
    };
  };

}).call(this);
