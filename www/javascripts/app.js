(function(/*! Brunch !*/) {
  'use strict';

  var globals = typeof window !== 'undefined' ? window : global;
  if (typeof globals.require === 'function') return;

  var modules = {};
  var cache = {};

  var has = function(object, name) {
    return ({}).hasOwnProperty.call(object, name);
  };

  var expand = function(root, name) {
    var results = [], parts, part;
    if (/^\.\.?(\/|$)/.test(name)) {
      parts = [root, name].join('/').split('/');
    } else {
      parts = name.split('/');
    }
    for (var i = 0, length = parts.length; i < length; i++) {
      part = parts[i];
      if (part === '..') {
        results.pop();
      } else if (part !== '.' && part !== '') {
        results.push(part);
      }
    }
    return results.join('/');
  };

  var dirname = function(path) {
    return path.split('/').slice(0, -1).join('/');
  };

  var localRequire = function(path) {
    return function(name) {
      var dir = dirname(path);
      var absolute = expand(dir, name);
      return globals.require(absolute, path);
    };
  };

  var initModule = function(name, definition) {
    var module = {id: name, exports: {}};
    definition(module.exports, localRequire(name), module);
    var exports = cache[name] = module.exports;
    return exports;
  };

  var require = function(name, loaderPath) {
    var path = expand(name, '.');
    if (loaderPath == null) loaderPath = '/';

    if (has(cache, path)) return cache[path];
    if (has(modules, path)) return initModule(path, modules[path]);

    var dirIndex = expand(path, './index');
    if (has(cache, dirIndex)) return cache[dirIndex];
    if (has(modules, dirIndex)) return initModule(dirIndex, modules[dirIndex]);

    throw new Error('Cannot find module "' + name + '" from '+ '"' + loaderPath + '"');
  };

  var define = function(bundle, fn) {
    if (typeof bundle === 'object') {
      for (var key in bundle) {
        if (has(bundle, key)) {
          modules[key] = bundle[key];
        }
      }
    } else {
      modules[bundle] = fn;
    }
  };

  var list = function() {
    var result = [];
    for (var item in modules) {
      if (has(modules, item)) {
        result.push(item);
      }
    }
    return result;
  };

  globals.require = require;
  globals.require.define = define;
  globals.require.register = define;
  globals.require.list = list;
  globals.require.brunch = true;
})();
require.register("application", function(exports, require, module) {
var LayoutView, Replicator;

Replicator = require('./lib/replicator');

LayoutView = require('./views/layout');

module.exports = {
  initialize: function() {
    var Router, e, locales,
      _this = this;

    window.app = this;
    this.polyglot = new Polyglot();
    try {
      locales = require('locales/' + this.locale);
    } catch (_error) {
      e = _error;
      locales = require('locales/en');
    }
    this.polyglot.extend(locales);
    window.t = this.polyglot.t.bind(this.polyglot);
    Router = require('router');
    this.router = new Router();
    this.layout = new LayoutView();
    $('body').empty().append(this.layout.render().$el);
    this.replicator = new Replicator();
    return this.replicator.init(function(err, config) {
      if (err) {
        console.log(err.stack);
      }
      if (err) {
        return alert(err.message);
      }
      Backbone.history.start();
      if (config) {
        return _this.router.navigate('folder/', {
          trigger: true
        });
      } else {
        return _this.router.navigate('config', {
          trigger: true
        });
      }
    });
  }
};

});

;require.register("collections/files", function(exports, require, module) {
var File, FileAndFolderCollection, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

File = require('../models/file');

module.exports = FileAndFolderCollection = (function(_super) {
  __extends(FileAndFolderCollection, _super);

  function FileAndFolderCollection() {
    _ref = FileAndFolderCollection.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  FileAndFolderCollection.prototype.model = File;

  FileAndFolderCollection.prototype.initialize = function(models, options) {
    this.path = options.path;
    return this.query = options.query;
  };

  FileAndFolderCollection.prototype.comparator = function(a, b) {
    var aname, atype, bname, btype, out;

    atype = a.get('docType').toLowerCase();
    btype = b.get('docType').toLowerCase();
    aname = a.get('name').toLowerCase();
    bname = b.get('name').toLowerCase();
    return out = atype < btype ? 1 : atype > btype ? -1 : aname > bname ? 2 : aname < bname ? -2 : 0;
  };

  FileAndFolderCollection.prototype.fetch = function(options) {
    var map, params, regexp,
      _this = this;

    map = params = null;
    if (this.query) {
      params = {};
      regexp = new RegExp(this.query, 'i');
      map = function(doc, emit) {
        var _ref1;

        if (((_ref1 = doc.docType) === 'Folder' || _ref1 === 'File') && regexp.test(doc.name)) {
          return emit(doc._id, doc);
        }
      };
    } else {
      params = {
        key: this.path ? '/' + this.path : ''
      };
      map = function(doc, emit) {
        var _ref1;

        if ((_ref1 = doc.docType) === 'Folder' || _ref1 === 'File') {
          return emit(doc.path, doc);
        }
      };
    }
    return app.replicator.db.query(map, params, function(err, response) {
      if (err) {
        return options != null ? typeof options.onError === "function" ? options.onError(err) : void 0 : void 0;
      }
      _this.reset(response.rows.map(function(row) {
        var binary_id;

        if (row.value.docType === 'File') {
          binary_id = row.value.binary.file.id;
          row.value.incache = app.replicator.binaryInCache(binary_id);
        }
        return row.value;
      }));
      return options != null ? typeof options.onSuccess === "function" ? options.onSuccess(_this) : void 0 : void 0;
    });
  };

  FileAndFolderCollection.prototype.fetchAdditional = function(options) {
    var folders;

    folders = this.where({
      docType: 'Folder'
    });
    return folders.forEach(function(folder) {
      return app.replicator.folderInCache(folder.toJSON(), function(err, incache) {
        if (err) {
          return console.log(err);
        }
        return folder.set('incache', incache);
      });
    });
  };

  return FileAndFolderCollection;

})(Backbone.Collection);

});

;require.register("initialize", function(exports, require, module) {
var app;

app = require('application');

document.addEventListener('deviceready', function() {
  return app.initialize();
});

});

;require.register("lib/base_view", function(exports, require, module) {
var BaseView, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

module.exports = BaseView = (function(_super) {
  __extends(BaseView, _super);

  function BaseView() {
    _ref = BaseView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  BaseView.prototype.template = function() {};

  BaseView.prototype.initialize = function() {};

  BaseView.prototype.getRenderData = function() {
    var _ref1;

    return {
      model: (_ref1 = this.model) != null ? _ref1.toJSON() : void 0
    };
  };

  BaseView.prototype.render = function() {
    this.beforeRender();
    this.$el.html(this.template(this.getRenderData()));
    this.afterRender();
    return this;
  };

  BaseView.prototype.beforeRender = function() {};

  BaseView.prototype.afterRender = function() {};

  BaseView.prototype.destroy = function() {
    this.undelegateEvents();
    this.$el.removeData().unbind();
    this.remove();
    return Backbone.View.prototype.remove.call(this);
  };

  return BaseView;

})(Backbone.View);

});

;require.register("lib/basic", function(exports, require, module) {
var b64, b64_enc;

b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

b64_enc = function(data) {
  var ac, bits, h1, h2, h3, h4, i, o1, o2, o3, out;

  if (!data) {
    return data;
  }
  i = 0;
  ac = 0;
  out = [];
  while (i < data.length) {
    o1 = data.charCodeAt(i++);
    o2 = data.charCodeAt(i++);
    o3 = data.charCodeAt(i++);
    bits = o1 << 16 | o2 << 8 | o3;
    h1 = bits >> 18 & 0x3f;
    h2 = bits >> 12 & 0x3f;
    h3 = bits >> 6 & 0x3f;
    h4 = bits & 0x3f;
    out[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4);
  }
  out = out.join('');
  switch (data.length % 3) {
    case 1:
      out = out.slice(0, -2) + '==';
      break;
    case 2:
      out = out.slice(0, -1) + '=';
  }
  return out;
};

module.exports = function(user, pass) {
  return 'Basic ' + b64_enc(user + ':' + pass);
};

});

;require.register("lib/replicator", function(exports, require, module) {
var DBNAME, REGEXP_PROCESS_STATUS, Replicator, basic, binariesInFolder, deleteEntry, getChildren, getFile, getOrCreateSubFolder, request, __chromeSafe,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

request = require('./request');

basic = require('./basic');

DBNAME = "cozy-files";

REGEXP_PROCESS_STATUS = /Processed (\d+) \/ (\d+) changes/;

__chromeSafe = function() {
  var FileTransfer;

  window.LocalFileSystem = {
    PERSISTENT: window.PERSISTENT
  };
  window.requestFileSystem = function(type, size, onSuccess, onError) {
    size = 5 * 1024 * 1024;
    return navigator.webkitPersistentStorage.requestQuota(size, function(granted) {
      return window.webkitRequestFileSystem(type, granted, onSuccess, onError);
    }, onError);
  };
  return window.FileTransfer = FileTransfer = (function() {
    function FileTransfer() {}

    FileTransfer.prototype.download = function(url, local, onSuccess, onError, _, options) {
      var key, value, xhr, _ref;

      xhr = new XMLHttpRequest();
      xhr.open('GET', url, true);
      xhr.overrideMimeType('text/plain; charset=x-user-defined');
      xhr.responseType = "arraybuffer";
      console.log("HERE", options.headers);
      _ref = options.headers;
      for (key in _ref) {
        value = _ref[key];
        xhr.setRequestHeader(key, value);
      }
      xhr.onreadystatechange = function() {
        if (xhr.readyState !== 4) {
          return;
        }
        return FileTransfer.fs.root.getFile(local, {
          create: true
        }, function(entry) {
          return entry.createWriter(function(writer) {
            var bb;

            writer.onwrite = function() {
              return onSuccess(entry);
            };
            writer.onerror = function(err) {
              return onError(err);
            };
            bb = new BlobBuilder();
            bb.append(xhr.response);
            return writer.write(bb.getBlob(mimetype));
          }, function(err) {
            return onError(err);
          });
        }, function(err) {
          return onError(err);
        });
      };
      return xhr.send(null);
    };

    return FileTransfer;

  })();
};

module.exports = Replicator = (function() {
  function Replicator() {
    this.folderInCache = __bind(this.folderInCache, this);
    this.binaryInCache = __bind(this.binaryInCache, this);
  }

  Replicator.prototype.db = null;

  Replicator.prototype.server = null;

  Replicator.prototype.config = null;

  Replicator.prototype.destroyDB = function(callback) {
    var _this = this;

    return this.db.destroy(function(err) {
      var onError, onSuccess;

      if (err) {
        return callback(err);
      }
      onError = function(err) {
        return callback(err);
      };
      onSuccess = function() {
        return callback(null);
      };
      return _this.downloads.removeRecursively(onSuccess, onError);
    });
  };

  Replicator.prototype.init = function(callback) {
    var _this = this;

    if (window.isBrowserDebugging) {
      __chromeSafe();
    }
    return this.initDownloadFolder(function(err) {
      var options;

      if (err) {
        return callback(err);
      }
      options = window.isBrowserDebugging ? {} : {
        adapter: 'websql'
      };
      _this.db = new PouchDB(DBNAME, options);
      return _this.db.get('localconfig', function(err, config) {
        if (err) {
          console.log(err);
          return callback(null, null);
        } else {
          _this.config = config;
          return callback(null, config);
        }
      });
    });
  };

  Replicator.prototype.initDownloadFolder = function(callback) {
    var onError, onSuccess, size,
      _this = this;

    onError = function(err) {
      return callback(err);
    };
    onSuccess = function(fs) {
      window.FileTransfer.fs = fs;
      return getOrCreateSubFolder(fs.root, 'cozy-downloads', function(err, downloads) {
        if (err) {
          return callback(err);
        }
        _this.downloads = downloads;
        return getChildren(downloads, function(err, children) {
          if (err) {
            return callback(err);
          }
          _this.cache = children;
          return callback(null);
        });
      });
    };
    if (window.isBrowserDebugging) {
      size = 5 * 1024 * 1024;
      return navigator.webkitPersistentStorage.requestQuota(size, function(granted) {
        return window.requestFileSystem(LocalFileSystem.PERSISTENT, granted, onSuccess, onError);
      }, onError);
    } else {
      return window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, onSuccess, onError);
    }
  };

  Replicator.prototype.registerRemote = function(config, callback) {
    var _this = this;

    return request.post({
      uri: "https://" + config.cozyURL + "/device/",
      auth: {
        username: 'owner',
        password: config.password
      },
      json: {
        login: config.deviceName,
        type: 'mobile'
      }
    }, function(err, response, body) {
      if (err) {
        return callback(err);
      } else if (response.statusCode === 401 && response.reason) {
        return callback(new Error('cozy need patch'));
      } else if (response.statusCode === 401) {
        return callback(new Error('wrong password'));
      } else if (response.statusCode === 400) {
        return callback(new Error('device name already exist'));
      } else {
        config.password = body.password;
        config.deviceId = body.id;
        config.auth = {
          username: config.deviceName,
          password: config.password
        };
        config.fullRemoteURL = ("https://" + config.deviceName + ":" + config.password) + ("@" + config.cozyURL + "/cozy");
        _this.config = config;
        _this.config._id = 'localconfig';
        return _this.saveConfig(callback);
      }
    });
  };

  Replicator.prototype.saveConfig = function(callback) {
    var _this = this;

    return this.db.put(this.config, function(err, result) {
      if (err) {
        return callback(err);
      }
      if (!result.ok) {
        return callback(new Error(JSON.stringify(result)));
      }
      _this.config._id = result.id;
      _this.config._rev = result.rev;
      return callback(null);
    });
  };

  Replicator.prototype.initialReplication = function(progressback, callback) {
    var auth, url,
      _this = this;

    url = "" + this.config.fullRemoteURL + "/_changes?descending=true&limit=1";
    auth = this.config.auth;
    progressback(0);
    return request.get({
      url: url,
      auth: auth,
      json: true
    }, function(err, res, body) {
      var last_seq;

      if (err) {
        return callback(err);
      }
      last_seq = body.last_seq;
      progressback(1 / 4);
      return _this.copyView('file', function(err) {
        if (err) {
          return callback(err);
        }
        progressback(2 / 4);
        return _this.copyView('folder', function(err) {
          if (err) {
            return callback(err);
          }
          progressback(3 / 4);
          _this.config.checkpointed = last_seq;
          return _this.saveConfig(callback);
        });
      });
    });
  };

  Replicator.prototype.copyView = function(model, callback) {
    var auth, url,
      _this = this;

    url = "" + this.config.fullRemoteURL + "/_design/" + model + "/_view/all/";
    auth = this.config.auth;
    return request.get({
      url: url,
      auth: auth,
      json: true
    }, function(err, res, body) {
      if (err) {
        return callback(err);
      }
      return async.each(body.rows, function(row, cb) {
        return _this.db.put(row.value, cb);
      }, function(err) {
        if (err) {
          return callback(err);
        }
        return callback(null);
      });
    });
  };

  Replicator.prototype.download = function(binary_id, local, progressback, callback) {
    var errors, ft, onError, onSuccess, options, url;

    url = encodeURI("https://" + this.config.cozyURL + "/cozy/" + binary_id + "/file");
    ft = new FileTransfer();
    errors = ['An error happened (UNKNOWN)', 'An error happened (NOT FOUND)', 'An error happened (INVALID URL)', 'This file isnt available offline', 'ABORTED'];
    onSuccess = function(entry) {
      return callback(null, entry);
    };
    onError = function(err) {
      return callback(new Error(errors[err.code]));
    };
    options = {
      headers: {
        Authorization: basic(this.config.deviceName, this.config.password)
      }
    };
    ft.onprogress = function(e) {
      if (e.lengthComputable) {
        return progressback(e.loaded, e.total);
      } else {
        return progressback(3, 10);
      }
    };
    return ft.download(url, local, onSuccess, onError, false, options);
  };

  Replicator.prototype.getFreeDiskSpace = function(callback) {
    var onSuccess;

    onSuccess = function(kBs) {
      return callback(null, kBs * 1024);
    };
    return cordova.exec(onSuccess, callback, 'File', 'getFreeDiskSpace', []);
  };

  Replicator.prototype.binaryInCache = function(binary_id) {
    return this.cache.some(function(entry) {
      return entry.name === binary_id;
    });
  };

  Replicator.prototype.folderInCache = function(folder, callback) {
    var _this = this;

    return this.db.query(binariesInFolder(folder), {}, function(err, result) {
      var ids;

      if (err) {
        return callback(err);
      }
      ids = result.rows.map(function(row) {
        return row.value.binary.file.id;
      });
      return callback(null, _.every(ids, _this.binaryInCache));
    });
  };

  Replicator.prototype.getBinary = function(model, callback, progressback) {
    var binary_id,
      _this = this;

    binary_id = model.binary.file.id;
    return getOrCreateSubFolder(this.downloads, binary_id, function(err, binfolder) {
      if (err) {
        return callback(err);
      }
      if (!model.name) {
        return callback(new Error('no model name :' + JSON.stringify(model)));
      }
      return getFile(binfolder, model.name, function(err, entry) {
        var local;

        if (entry) {
          return callback(null, entry.toURL());
        }
        local = binfolder.toURL() + '/' + model.name;
        return _this.download(binary_id, local, progressback, function(err, entry) {
          if (err) {
            return deleteEntry(binfolder, function(delerr) {
              return callback(err);
            });
          } else {
            _this.cache.push(binfolder);
            return callback(null, entry.toURL());
          }
        });
      });
    });
  };

  Replicator.prototype.getBinaryFolder = function(folder, callback, progressback) {
    var _this = this;

    console.log("GBININFOLDER");
    return this.db.query(binariesInFolder(folder), {}, function(err, result) {
      var sizes, totalSize;

      if (err) {
        return callback(err);
      }
      sizes = result.rows.map(function(row) {
        return row.value.size;
      });
      totalSize = sizes.reduce(function(a, b) {
        return a + b;
      });
      return _this.getFreeDiskSpace(function(err, available) {
        var progressHandlers, reportProgress;

        console.log("GFDS RESULT = " + available);
        if (err) {
          return callback(err);
        }
        if (totalSize > available) {
          alert('There is not enough disk space, try download sub-folders.');
          return callback(null);
        } else {
          progressHandlers = {};
          reportProgress = function() {
            var done, key, status, total;

            total = done = 0;
            for (key in progressHandlers) {
              status = progressHandlers[key];
              done += status[0];
              total += status[1];
            }
            return progressback(done, total);
          };
          return async.each(result.rows, function(row, cb) {
            console.log("DOWNLOAD", row.name);
            return _this.getBinary(row.value, cb, function(done, total) {
              progressHandlers[row.value._id] = [done, total];
              return reportProgress();
            });
          }, function() {
            if (err) {
              return callback(err);
            }
            app.router.bustCache(folder.path + '/' + folder.name);
            return callback();
          });
        }
      });
    });
  };

  Replicator.prototype.removeLocal = function(model, callback) {
    var binary_id, onBinFolderFound,
      _this = this;

    binary_id = model.binary.file.id;
    console.log("REMOVE LOCAL");
    console.log(binary_id);
    onBinFolderFound = function(binfolder) {
      var onSuccess;

      onSuccess = function() {
        var entry, index, _i, _len, _ref;

        _ref = _this.cache;
        for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
          entry = _ref[index];
          if (!(entry.name === binary_id)) {
            continue;
          }
          _this.cache.splice(index, 1);
          break;
        }
        return callback(null);
      };
      return binfolder.removeRecursively(onSuccess, callback);
    };
    return this.downloads.getDirectory(binary_id, {}, onBinFolderFound, callback);
  };

  Replicator.prototype.removeLocalFolder = function(folder, callback) {
    var _this = this;

    return this.db.query(binariesInFolder(folder), {}, function(err, result) {
      var ids;

      if (err) {
        return callback(err);
      }
      ids = result.rows.map(function(row) {
        return row.value.binary.file.id;
      });
      return async.eachSeries(ids, function(id, cb) {
        return _this.removeLocal({
          binary: {
            file: {
              id: id
            }
          }
        }, cb);
      }, function(err) {
        if (err) {
          return callback(err);
        }
        app.router.bustCache(folder.path + '/' + folder.name);
        return callback();
      });
    });
  };

  Replicator.prototype.sync = function(callback) {
    var _this = this;

    return this.db.replicate.from(this.config.fullRemoteURL, {
      filter: "" + this.config.deviceId + "/filter",
      since: this.config.checkpointed,
      complete: function(err, result) {
        _this.config.checkpointed = result.last_seq;
        return _this.saveConfig(callback);
      }
    });
  };

  return Replicator;

})();

binariesInFolder = function(folder) {
  var path;

  path = folder.path + '/' + folder.name;
  return function(doc, emit) {
    var _ref;

    if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file' && doc.path.indexOf(path) === 0) {
      return emit(doc._id, doc);
    }
  };
};

deleteEntry = function(entry, callback) {
  var onError, onSuccess;

  onSuccess = function() {
    return callback(null);
  };
  onError = function(err) {
    return callback(err);
  };
  return entry.remove(onSuccess, onError);
};

getFile = function(parent, name, callback) {
  var onError, onSuccess;

  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return parent.getFile(name, null, onSuccess, onError);
};

getOrCreateSubFolder = function(parent, name, callback) {
  var onError, onSuccess;

  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return parent.getDirectory(name, {
    create: true
  }, onSuccess, onError);
};

getChildren = function(directory, callback) {
  var onError, onSuccess, reader;

  reader = directory.createReader();
  onSuccess = function(entries) {
    return callback(null, entries);
  };
  onError = function(err) {
    return callback(err);
  };
  return reader.readEntries(onSuccess, onError);
};

});

;require.register("lib/request", function(exports, require, module) {
// Browser Request
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

var XHR = XMLHttpRequest
if (!XHR) throw new Error('missing XMLHttpRequest')
request.log = {
  'trace': noop, 'debug': noop, 'info': noop, 'warn': noop, 'error': noop
}

var DEFAULT_TIMEOUT = 3 * 60 * 1000 // 3 minutes

//
// request
//

function request(options, callback) {
  // The entry-point to the API: prep the options object and pass the real work to run_xhr.
  if(typeof callback !== 'function')
    throw new Error('Bad callback given: ' + callback)

  if(!options)
    throw new Error('No options given')

  var options_onResponse = options.onResponse; // Save this for later.

  if(typeof options === 'string')
    options = {'uri':options};
  else
    options = JSON.parse(JSON.stringify(options)); // Use a duplicate for mutating.

  options.onResponse = options_onResponse // And put it back.

  if (options.verbose) request.log = getLogger();

  if(options.url) {
    options.uri = options.url;
    delete options.url;
  }

  if(!options.uri && options.uri !== "")
    throw new Error("options.uri is a required argument");

  if(typeof options.uri != "string")
    throw new Error("options.uri must be a string");

  var unsupported_options = ['proxy', '_redirectsFollowed', 'maxRedirects', 'followRedirect']
  for (var i = 0; i < unsupported_options.length; i++)
    if(options[ unsupported_options[i] ])
      throw new Error("options." + unsupported_options[i] + " is not supported")

  options.callback = callback
  options.method = options.method || 'GET';
  options.headers = options.headers || {};
  options.body    = options.body || null
  options.timeout = options.timeout || request.DEFAULT_TIMEOUT

  if(options.headers.host)
    throw new Error("Options.headers.host is not supported");

  if(options.json) {
    options.headers.accept = options.headers.accept || 'application/json'
    if(options.method !== 'GET')
      options.headers['content-type'] = 'application/json'

    if(typeof options.json !== 'boolean')
      options.body = JSON.stringify(options.json)
    else if(typeof options.body !== 'string')
      options.body = JSON.stringify(options.body)
  }

  //BEGIN QS Hack
  var serialize = function(obj) {
    var str = [];
    for(var p in obj)
      if (obj.hasOwnProperty(p)) {
        str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
      }
    return str.join("&");
  }

  if(options.qs){
    var qs = (typeof options.qs == 'string')? options.qs : serialize(options.qs);
    if(options.uri.indexOf('?') !== -1){ //no get params
        options.uri = options.uri+'&'+qs;
    }else{ //existing get params
        options.uri = options.uri+'?'+qs;
    }
  }
  //END QS Hack

  //BEGIN FORM Hack
  var multipart = function(obj) {
    //todo: support file type (useful?)
    var result = {};
    result.boundry = '-------------------------------'+Math.floor(Math.random()*1000000000);
    var lines = [];
    for(var p in obj){
        if (obj.hasOwnProperty(p)) {
            lines.push(
                '--'+result.boundry+"\n"+
                'Content-Disposition: form-data; name="'+p+'"'+"\n"+
                "\n"+
                obj[p]+"\n"
            );
        }
    }
    lines.push( '--'+result.boundry+'--' );
    result.body = lines.join('');
    result.length = result.body.length;
    result.type = 'multipart/form-data; boundary='+result.boundry;
    return result;
  }

  if(options.form){
    if(typeof options.form == 'string') throw('form name unsupported');
    if(options.method === 'POST'){
        var encoding = (options.encoding || 'application/x-www-form-urlencoded').toLowerCase();
        options.headers['content-type'] = encoding;
        switch(encoding){
            case 'application/x-www-form-urlencoded':
                options.body = serialize(options.form).replace(/%20/g, "+");
                break;
            case 'multipart/form-data':
                var multi = multipart(options.form);
                //options.headers['content-length'] = multi.length;
                options.body = multi.body;
                options.headers['content-type'] = multi.type;
                break;
            default : throw new Error('unsupported encoding:'+encoding);
        }
    }
  }
  //END FORM Hack

  // If onResponse is boolean true, call back immediately when the response is known,
  // not when the full request is complete.
  options.onResponse = options.onResponse || noop
  if(options.onResponse === true) {
    options.onResponse = callback
    options.callback = noop
  }

  // XXX Browsers do not like this.
  //if(options.body)
  //  options.headers['content-length'] = options.body.length;

  // HTTP basic authentication
  if(!options.headers.authorization && options.auth)
    options.headers.authorization = 'Basic ' + b64_enc(options.auth.username + ':' + options.auth.password);

  return run_xhr(options)
}

var req_seq = 0
function run_xhr(options) {
  var xhr = new XHR
    , timed_out = false
    , is_cors = is_crossDomain(options.uri)
    , supports_cors = ('withCredentials' in xhr)

  req_seq += 1
  xhr.seq_id = req_seq
  xhr.id = req_seq + ': ' + options.method + ' ' + options.uri
  xhr._id = xhr.id // I know I will type "_id" from habit all the time.

  if(is_cors && !supports_cors) {
    var cors_err = new Error('Browser does not support cross-origin request: ' + options.uri)
    cors_err.cors = 'unsupported'
    return options.callback(cors_err, xhr)
  }

  xhr.timeoutTimer = setTimeout(too_late, options.timeout)
  function too_late() {
    timed_out = true
    var er = new Error('ETIMEDOUT')
    er.code = 'ETIMEDOUT'
    er.duration = options.timeout

    request.log.error('Timeout', { 'id':xhr._id, 'milliseconds':options.timeout })
    return options.callback(er, xhr)
  }

  // Some states can be skipped over, so remember what is still incomplete.
  var did = {'response':false, 'loading':false, 'end':false}

  xhr.onreadystatechange = on_state_change
  xhr.open(options.method, options.uri, true) // asynchronous
  if(is_cors)
    xhr.withCredentials = !! options.withCredentials
  xhr.send(options.body)
  return xhr

  function on_state_change(event) {
    if(timed_out)
      return request.log.debug('Ignoring timed out state change', {'state':xhr.readyState, 'id':xhr.id})

    request.log.debug('State change', {'state':xhr.readyState, 'id':xhr.id, 'timed_out':timed_out})

    if(xhr.readyState === XHR.OPENED) {
      request.log.debug('Request started', {'id':xhr.id})
      for (var key in options.headers)
        xhr.setRequestHeader(key, options.headers[key])
    }

    else if(xhr.readyState === XHR.HEADERS_RECEIVED)
      on_response()

    else if(xhr.readyState === XHR.LOADING) {
      on_response()
      on_loading()
    }

    else if(xhr.readyState === XHR.DONE) {
      on_response()
      on_loading()
      on_end()
    }
  }

  function on_response() {
    if(did.response)
      return

    did.response = true
    request.log.debug('Got response', {'id':xhr.id, 'status':xhr.status})
    clearTimeout(xhr.timeoutTimer)
    xhr.statusCode = xhr.status // Node request compatibility

    // Detect failed CORS requests.
    if(is_cors && xhr.statusCode == 0) {
      var cors_err = new Error('CORS request rejected: ' + options.uri)
      cors_err.cors = 'rejected'

      // Do not process this request further.
      did.loading = true
      did.end = true

      return options.callback(cors_err, xhr)
    }

    options.onResponse(null, xhr)
  }

  function on_loading() {
    if(did.loading)
      return

    did.loading = true
    request.log.debug('Response body loading', {'id':xhr.id})
    // TODO: Maybe simulate "data" events by watching xhr.responseText
  }

  function on_end() {
    if(did.end)
      return

    did.end = true
    request.log.debug('Request done', {'id':xhr.id})

    xhr.body = xhr.responseText
    if(options.json) {
      try        { xhr.body = JSON.parse(xhr.responseText) }
      catch (er) { return options.callback(er, xhr)        }
    }

    options.callback(null, xhr, xhr.body)
  }

} // request

request.withCredentials = false;
request.DEFAULT_TIMEOUT = DEFAULT_TIMEOUT;

//
// defaults
//

request.defaults = function(options, requester) {
  var def = function (method) {
    var d = function (params, callback) {
      if(typeof params === 'string')
        params = {'uri': params};
      else {
        params = JSON.parse(JSON.stringify(params));
      }
      for (var i in options) {
        if (params[i] === undefined) params[i] = options[i]
      }
      return method(params, callback)
    }
    return d
  }
  var de = def(request)
  de.get = def(request.get)
  de.post = def(request.post)
  de.put = def(request.put)
  de.head = def(request.head)
  return de
}

//
// HTTP method shortcuts
//

var shortcuts = [ 'get', 'put', 'post', 'head' ];
shortcuts.forEach(function(shortcut) {
  var method = shortcut.toUpperCase();
  var func   = shortcut.toLowerCase();

  request[func] = function(opts) {
    if(typeof opts === 'string')
      opts = {'method':method, 'uri':opts};
    else {
      opts = JSON.parse(JSON.stringify(opts));
      opts.method = method;
    }

    var args = [opts].concat(Array.prototype.slice.apply(arguments, [1]));
    return request.apply(this, args);
  }
})

//
// CouchDB shortcut
//

request.couch = function(options, callback) {
  if(typeof options === 'string')
    options = {'uri':options}

  // Just use the request API to do JSON.
  options.json = true
  if(options.body)
    options.json = options.body
  delete options.body

  callback = callback || noop

  var xhr = request(options, couch_handler)
  return xhr

  function couch_handler(er, resp, body) {
    if(er)
      return callback(er, resp, body)

    if((resp.statusCode < 200 || resp.statusCode > 299) && body.error) {
      // The body is a Couch JSON object indicating the error.
      er = new Error('CouchDB error: ' + (body.error.reason || body.error.error || body.error))
      for (var key in body)
        er[key] = body[key]
      return callback(er, resp, body);
    }

    return callback(er, resp, body);
  }
}

//
// Utility
//

function noop() {}

function getLogger() {
  var logger = {}
    , levels = ['trace', 'debug', 'info', 'warn', 'error']
    , level, i

  for(i = 0; i < levels.length; i++) {
    level = levels[i]

    logger[level] = noop
    if(typeof console !== 'undefined' && console && console[level])
      logger[level] = formatted(console, level)
  }

  return logger
}

function formatted(obj, method) {
  return formatted_logger

  function formatted_logger(str, context) {
    if(typeof context === 'object')
      str += ' ' + JSON.stringify(context)

    return obj[method].call(obj, str)
  }
}

// Return whether a URL is a cross-domain request.
function is_crossDomain(url) {
  var rurl = /^([\w\+\.\-]+:)(?:\/\/([^\/?#:]*)(?::(\d+))?)?/

  // jQuery #8138, IE may throw an exception when accessing
  // a field from window.location if document.domain has been set
  var ajaxLocation
  try { ajaxLocation = location.href }
  catch (e) {
    // Use the href attribute of an A element since IE will modify it given document.location
    ajaxLocation = document.createElement( "a" );
    ajaxLocation.href = "";
    ajaxLocation = ajaxLocation.href;
  }

  var ajaxLocParts = rurl.exec(ajaxLocation.toLowerCase()) || []
    , parts = rurl.exec(url.toLowerCase() )

  var result = !!(
    parts &&
    (  parts[1] != ajaxLocParts[1]
    || parts[2] != ajaxLocParts[2]
    || (parts[3] || (parts[1] === "http:" ? 80 : 443)) != (ajaxLocParts[3] || (ajaxLocParts[1] === "http:" ? 80 : 443))
    )
  )

  //console.debug('is_crossDomain('+url+') -> ' + result)
  return result
}

// MIT License from http://phpjs.org/functions/base64_encode:358
function b64_enc (data) {
    // Encodes string using MIME base64 algorithm
    var b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var o1, o2, o3, h1, h2, h3, h4, bits, i = 0, ac = 0, enc="", tmp_arr = [];

    if (!data) {
        return data;
    }

    // assume utf8 data
    // data = this.utf8_encode(data+'');

    do { // pack three octets into four hexets
        o1 = data.charCodeAt(i++);
        o2 = data.charCodeAt(i++);
        o3 = data.charCodeAt(i++);

        bits = o1<<16 | o2<<8 | o3;

        h1 = bits>>18 & 0x3f;
        h2 = bits>>12 & 0x3f;
        h3 = bits>>6 & 0x3f;
        h4 = bits & 0x3f;

        // use hexets to index into b64, and append result to encoded string
        tmp_arr[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4);
    } while (i < data.length);

    enc = tmp_arr.join('');

    switch (data.length % 3) {
        case 1:
            enc = enc.slice(0, -2) + '==';
        break;
        case 2:
            enc = enc.slice(0, -1) + '=';
        break;
    }

    return enc;
}
module.exports = request;
});

;require.register("lib/url", function(exports, require, module) {
var a;

a = document.createElement('a');

module.exports = function(url) {
  var result;

  a.href = url;
  return result = {
    host: a.host,
    hostname: a.hostname,
    pathname: a.pathname,
    port: a.port,
    protocol: a.protocol,
    search: a.search,
    hash: a.hash
  };
};

});

;require.register("lib/view_collection", function(exports, require, module) {
var BaseView, ViewCollection, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('lib/base_view');

module.exports = ViewCollection = (function(_super) {
  __extends(ViewCollection, _super);

  function ViewCollection() {
    this.removeItem = __bind(this.removeItem, this);
    this.addItem = __bind(this.addItem, this);    _ref = ViewCollection.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  ViewCollection.prototype.itemview = null;

  ViewCollection.prototype.views = {};

  ViewCollection.prototype.template = function() {
    return '';
  };

  ViewCollection.prototype.itemViewOptions = function() {};

  ViewCollection.prototype.collectionEl = null;

  ViewCollection.prototype.onChange = function() {
    return this.$el.toggleClass('empty', _.size(this.views) === 0);
  };

  ViewCollection.prototype.appendView = function(view) {
    return this.$collectionEl.append(view.el);
  };

  ViewCollection.prototype.initialize = function() {
    ViewCollection.__super__.initialize.apply(this, arguments);
    this.views = {};
    this.listenTo(this.collection, "reset", this.onReset);
    this.listenTo(this.collection, "add", this.addItem);
    this.listenTo(this.collection, "remove", this.removeItem);
    if (this.collectionEl == null) {
      this.collectionEl = this.el;
      return this.$collectionEl = this.$el;
    }
  };

  ViewCollection.prototype.render = function() {
    var id, view, _ref1;

    _ref1 = this.views;
    for (id in _ref1) {
      view = _ref1[id];
      view.$el.detach();
    }
    return ViewCollection.__super__.render.apply(this, arguments);
  };

  ViewCollection.prototype.afterRender = function() {
    var id, view, _ref1;

    if (!this.$collectionEl) {
      this.$collectionEl = this.$(this.collectionEl);
    }
    _ref1 = this.views;
    for (id in _ref1) {
      view = _ref1[id];
      this.appendView(view);
    }
    this.onReset(this.collection);
    return this.onChange(this.views);
  };

  ViewCollection.prototype.remove = function() {
    this.onReset([]);
    return ViewCollection.__super__.remove.apply(this, arguments);
  };

  ViewCollection.prototype.onReset = function(newcollection) {
    var id, view, _ref1;

    _ref1 = this.views;
    for (id in _ref1) {
      view = _ref1[id];
      view.remove();
    }
    return newcollection.forEach(this.addItem);
  };

  ViewCollection.prototype.addItem = function(model) {
    var options, view;

    options = _.extend({}, {
      model: model
    }, this.itemViewOptions(model));
    view = new this.itemview(options);
    this.views[model.cid] = view.render();
    this.appendView(view);
    return this.onChange(this.views);
  };

  ViewCollection.prototype.removeItem = function(model) {
    this.views[model.cid].remove();
    delete this.views[model.cid];
    return this.onChange(this.views);
  };

  return ViewCollection;

})(BaseView);

});

;require.register("locales/en", function(exports, require, module) {
module.exports = {
  "Add": "Add",
  "alarm": "Alarm",
  "event": "Event",
  "add the alarm": "add the alarm",
  "create alarm": "Alarm creation",
  "create event": "Event creation",
  "edit alarm": "Alarm edition",
  "edit event": "Event edition",
  "edit": "Edit",
  "create": "Create",
  "creation": "Creation",
  "invite": "Invite",
  "close": "Close",
  "delete": "Delete",
  "Place": "Place",
  "description": "Description",
  "date": "date",
  "Day": "Day",
  "Edit": "Edit",
  "Email": "Email",
  "Import": "Import",
  "Export": "Export",
  "List": "List",
  "list": "list",
  "Calendar": "Calendar",
  "calendar": "Calendar",
  "Sync": "Sync",
  "ie: 9:00 important meeting": "ie: 9:00 important meeting",
  "Month": "Month",
  "Popup": "Popup",
  "Switch to List": "Switch to List",
  "Switch to Calendar": "Switch to Calendar",
  "time": "time",
  "Today": "Today",
  "What should I remind you ?": "What should I remind you?",
  "alarm description placeholder": "What do you want to be reminded?",
  "ICalendar import": "ICalendar import",
  "select an icalendar file": "Select an icalendar file",
  "import your icalendar file": "import your icalendar file",
  "confirm import": "confirm import",
  "cancel": "cancel",
  "Create": "Create",
  "Alarms to import": "Alarms to import",
  "Events to import": "Events to import",
  "Create Event": "Create Event",
  "From hours:minutes": "From hours:minutes",
  "To hours:minutes+days": "To hours:minutes+days",
  "Description": "Description",
  "days after": "days after",
  "days later": "days later",
  "Week": "Semaine",
  "Alarms": "Alarms",
  "Display": "Notification",
  "DISPLAY": "Notification",
  "EMAIL": "E-mail",
  "BOTH": "E-mail & Notification",
  "display previous events": "Display previous events",
  "event": "Event",
  "alarm": "Alarm",
  "are you sure": "Are you sure ?",
  "advanced": "More details",
  "enter email": "Enter email",
  "ON": "on",
  "OFF": "off",
  "recurrence": "Recurrence",
  "recurrence rule": "Recurrence rules",
  "make reccurent": "Make recurrent",
  "repeat every": "Repeat every",
  "no recurrence": "No recurrence",
  "repeat on": "Repeat on",
  "repeat on date": "Repeat on dates",
  "repeat on weekday": "Repeat on weekday",
  "repeat until": "Repeat until",
  "after": "After",
  "repeat": "Repeat",
  "forever": "Forever",
  "occurences": "occurences",
  "every": "Every",
  "days": "days",
  "day": "day",
  "weeks": "weeks",
  "week": "week",
  "months": "months",
  "month": "month",
  "years": "years",
  "year": "year",
  "until": "until",
  "for": "for",
  "on": "on",
  "on the": "on the",
  "th": "th",
  "nd": "nd",
  "rd": "rd",
  "st": "st",
  "last": "last",
  "and": "and",
  "times": "times",
  "weekday": "weekday",
  "summary": "Summary",
  "place": "Place",
  "start": "Start",
  "end": "End",
  "tags": "Tags",
  "add tags": "Add tags",
  "change": "Change",
  "change calendar": "Change calendar",
  "save changes": "Save changes",
  "save changes and invite guests": "Save changes and invite guests",
  "guests": "Guests",
  "no description": "A title must be set.",
  "start after end": "The start date is after the end date.",
  "invalid start date": "The start date is invalid.",
  "invalid end date": "The end date is invalid.",
  "invalid trigg date": "The date is invalid.",
  "invalid action": "The action is invalid."
};

});

;require.register("models/file", function(exports, require, module) {
var File, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

module.exports = File = (function(_super) {
  __extends(File, _super);

  function File() {
    _ref = File.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  File.prototype.idAttribute = "_id";

  File.prototype.defaults = function() {
    return {
      incache: 'loading'
    };
  };

  return File;

})(Backbone.Model);

});

;require.register("router", function(exports, require, module) {
var ConfigRunView, ConfigView, FolderCollection, FolderView, Router, app, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

app = require('application');

FolderView = require('./views/folder');

ConfigView = require('./views/config');

ConfigRunView = require('./views/config_run');

FolderCollection = require('./collections/files');

module.exports = Router = (function(_super) {
  var cache, cacheChildren, cacheOrPrepare, timeouts;

  __extends(Router, _super);

  function Router() {
    _ref = Router.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Router.prototype.routes = {
    'folder/*path': 'folder',
    'search/*query': 'search',
    'config': 'login',
    'configrun': 'config'
  };

  Router.prototype.folder = function(path) {
    var backpath,
      _this = this;

    $('#btn-menu, #btn-back').show();
    if (path === null) {
      app.layout.setBackButton('#folder/', 'home');
    } else {
      backpath = '#folder/' + path.split('/').slice(0, -1);
      app.layout.setBackButton(backpath, 'ios7-arrow-back');
    }
    return cacheOrPrepare(path, function(err, collection) {
      if (err) {
        return alert(err);
      }
      return _this.display(new FolderView({
        collection: collection
      }));
    });
  };

  Router.prototype.search = function(query) {
    var collection,
      _this = this;

    $('#btn-menu, #btn-back').show();
    app.layout.setBackButton('#folder/', 'home');
    collection = new FolderCollection([], {
      query: query
    });
    return collection.fetch({
      onError: function(err) {
        return alert(err);
      },
      onSuccess: function() {
        $('#search-input').blur();
        return _this.display(new FolderView({
          collection: collection
        }));
      }
    });
  };

  Router.prototype.login = function() {
    $('#btn-menu, #btn-back').hide();
    return this.display(new ConfigView());
  };

  Router.prototype.config = function() {
    $('#btn-back').hide();
    return this.display(new ConfigRunView());
  };

  Router.prototype.display = function(view) {
    var direction;

    if (this.mainView instanceof FolderView && view instanceof FolderView) {
      direction = this.mainView.isParentOf(view) ? 'left' : 'right';
    } else {
      direction = 'none';
    }
    return app.layout.transitionTo(view, direction);
  };

  Router.prototype.bustCache = function(path) {
    path = path.substr(1);
    console.log("BUST");
    console.log(path);
    console.log(cache[path]);
    delete cache[path];
    return setTimeout(cacheChildren.bind(null, null, [path]), 10);
  };

  cache = {};

  timeouts = {};

  cacheChildren = function(collection, array) {
    var parent, path,
      _this = this;

    if (collection) {
      cache = {};
      array = collection.filter(function(model) {
        var _ref1;

        return ((_ref1 = model.get('docType')) != null ? typeof _ref1.toLowerCase === "function" ? _ref1.toLowerCase() : void 0 : void 0) === 'folder';
      });
      array = array.map(function(model) {
        return (model.get('path') + '/' + model.get('name')).substr(1);
      });
      parent = (collection.path || '/fake').split('/').slice(0, -1).join('/');
      array.push(parent);
    }
    if (array.length === 0) {
      return;
    }
    path = array.shift();
    collection = new FolderCollection([], {
      path: path
    });
    return collection.fetch({
      onError: function(err) {
        console.log(err);
        return cacheChildren(null, array);
      },
      onSuccess: function() {
        cache[path] = collection;
        return cacheChildren(null, array);
      }
    });
  };

  cacheOrPrepare = function(path, callback) {
    var collection, incache,
      _this = this;

    if (!path) {
      path = "";
    }
    if (incache = cache[path]) {
      setTimeout(cacheChildren.bind(null, incache), 10);
      return callback(null, incache);
    }
    console.log('CACHE MISS');
    collection = new FolderCollection([], {
      path: path
    });
    return collection.fetch({
      onError: function(err) {
        return cb(err);
      },
      onSuccess: function() {
        callback(null, collection);
        return setTimeout(cacheChildren.bind(null, collection), 10);
      }
    });
  };

  return Router;

})(Backbone.Router);

});

;require.register("templates/config", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<label class="item item-input"><span class="input-label">');
var __val__ = t('cozy url')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input id="input-url" type="text"/></label><label class="item item-input"><span class="input-label">');
var __val__ = t('cozy password')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input id="input-pass" type="password"/></label><label class="item item-input"><span class="input-label">');
var __val__ = t('device name')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input id="input-device" type="text"/></label><button id="btn-save" class="button button-block button-balanced">Save</button>');
}
return buf.join("");
};
});

;require.register("templates/folder_line", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="item-content">');
if ( model.docType == 'Folder')
{
buf.push('<i class="icon ion-folder"></i>');
}
else
{
buf.push('<i class="icon ion-document"></i>');
}
buf.push('<span>');
var __val__ = model.name
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span>');
if ( model.docType == 'Folder')
{
buf.push('<i class="icon ion-chevron-right"></i>');
}
else if ( model.incache)
{
buf.push('<i class="cache-indicator icon ion-ios7-download-outline"></i>');
}
else
{
buf.push('<i class="cache-indicator icon ion-ios7-cloud-download-outline"></i>');
}
buf.push('</div><div class="item-options invisible">');
if ( model.incache == 'loading')
{
buf.push('<div class="button">Loading</div>');
}
else if ( model.incache)
{
buf.push('<div class="button uncache">Remove local</div>');
}
else
{
buf.push('<div class="button download">Download</div>');
}
buf.push('</div>');
}
return buf.join("");
};
});

;require.register("templates/folder_modal", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="modal-backdrop"><div class="modal-wrapper"><div class="modal"><div class="bar bar-header"><h1 class="title">');
var __val__ = name
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</h1><button class="close button button-clear button-positive">Cancel</button></div><div class="content has-header"><div class="list"><div style="margin: -1px 0px" class="item item-toggle">Enable offline access<label class="toggle"><input');
buf.push(attrs({ 'type':("checkbox"), 'checked':(offline), 'disabled':(forced), "class": ('offline-checkbox') }, {"type":true,"checked":true,"disabled":true}));
buf.push('/><div class="track"><div class="handle"></div></div></label></div>');
if ( forced)
{
buf.push('This folder is too big to be made available offline.\nChange its subfolders items.');
}
buf.push('</div></div></div></div></div>');
}
return buf.join("");
};
});

;require.register("templates/layout", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div id="container" class="pane"><div class="bar bar-header bar-calm"><a id="btn-menu" class="button button-icon icon ion-navicon-round"></a><h1 class="title">Cozy Files</h1></div><div id="viewsPlaceholder" class="scroll-content has-header has-footer"></div><div class="bar bar-footer"><a id="btn-back" class="button button-icon icon ion-ios7-arrow-back"></a></div></div>');
}
return buf.join("");
};
});

;require.register("templates/menu", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="bar bar-header bar-dark"><h1 class="title">Menu</h1></div><div class="content has-header"><div class="item item-input-inset"><label class="item-input-wrapper"><input id="search-input" type="text" placeholder="Search"/></label><a id="btn-search" class="button button-icon icon ion-search"></a></div><a href="#folder/" class="item item-icon-left"><i class="icon ion-home"></i>Home</a><a href="#configrun" class="item item-icon-left"><i class="icon ion-wrench"></i>Config</a><a id="refresher" class="item item-icon-left"><i class="icon ion-loop"></i>Refresh</a></div>');
}
return buf.join("");
};
});

;require.register("views/config", function(exports, require, module) {
var BaseView, ConfigView, urlparse, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

urlparse = require('../lib/url');

module.exports = ConfigView = (function(_super) {
  __extends(ConfigView, _super);

  function ConfigView() {
    _ref = ConfigView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  ConfigView.prototype.className = 'list';

  ConfigView.prototype.template = require('../templates/config');

  ConfigView.prototype.events = function() {
    return {
      'click #btn-save': 'doSave'
    };
  };

  ConfigView.prototype.doSave = function() {
    var config, device, pass, url,
      _this = this;

    if (this.saving) {
      return null;
    }
    this.saving = $('#btn-save').text();
    if (this.error) {
      this.error.remove();
    }
    url = this.$('#input-url').val();
    pass = this.$('#input-pass').val();
    device = this.$('#input-device').val();
    if (!(url && pass && device)) {
      return this.displayError('all fields are required');
    }
    if (url.slice(0, 4) === 'http') {
      this.$('#input-url').val(url = urlparse(url).hostname);
    }
    config = {
      cozyURL: url,
      password: pass,
      deviceName: device
    };
    $('#btn-save').text('registering ...');
    return app.replicator.registerRemote(config, function(err) {
      var onProgress;

      if (err) {
        return _this.displayError(err.message);
      }
      onProgress = function(percent) {
        return $('#btn-save').text('downloading hierarchy ' + parseInt(percent * 100) + '%');
      };
      return app.replicator.initialReplication(onProgress, function(err) {
        if (err) {
          return _this.displayError(err.message);
        }
        $('#footer').text('replication complete');
        return app.router.navigate('folder/', {
          trigger: true
        });
      });
    });
  };

  ConfigView.prototype.displayError = function(text, field) {
    $('#btn-save').text(this.saving);
    this.saving = false;
    if (this.error) {
      this.error.remove();
    }
    if (~text.indexOf('CORS request rejected')) {
      text = 'Connection faillure';
    }
    this.error = $('<div>').addClass('button button-full button-energized');
    this.error.text(text);
    return this.$(field || '#btn-save').before(this.error);
  };

  return ConfigView;

})(BaseView);

});

;require.register("views/config_run", function(exports, require, module) {
var BaseView, ConfigView, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = ConfigView = (function(_super) {
  __extends(ConfigView, _super);

  function ConfigView() {
    _ref = ConfigView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  ConfigView.prototype.template = function() {
    return "<button id=\"redbtn\" class=\"button button-block button-assertive\">Reset</button>\n<p>This will erase all cozy-files generated data on your device.</p>";
  };

  ConfigView.prototype.events = function() {
    return {
      'click #redbtn': 'redBtn'
    };
  };

  ConfigView.prototype.redBtn = function() {
    var _this = this;

    if (confirm("Are you sure ?")) {
      return app.replicator.destroyDB(function(err) {
        if (err) {
          return _this.displayError(err.message, '#redbtn');
        }
        $('#redbtn').text('DONE');
        return window.location.reload(true);
      });
    }
  };

  ConfigView.prototype.displayError = function(text, field) {
    if (this.error) {
      this.error.remove();
    }
    this.error = $('<div>').addClass('button button-full button-energized');
    this.error.text(text);
    return this.$(field).before(this.error);
  };

  return ConfigView;

})(BaseView);

});

;require.register("views/folder", function(exports, require, module) {
var CollectionView, FolderView, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

CollectionView = require('../lib/view_collection');

module.exports = FolderView = (function(_super) {
  __extends(FolderView, _super);

  function FolderView() {
    this.displaySlider = __bind(this.displaySlider, this);
    this.appendView = __bind(this.appendView, this);    _ref = FolderView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  FolderView.prototype.className = 'list';

  FolderView.prototype.itemview = require('./folder_line');

  FolderView.prototype.events = function() {
    return {
      'click .cache-indicator': 'displaySlider'
    };
  };

  FolderView.prototype.isParentOf = function(otherFolderView) {
    if (this.collection.path === null) {
      return true;
    }
    if (this.collection.path === void 0) {
      return false;
    }
    if (!otherFolderView.collection.path) {
      return false;
    }
    return -1 !== otherFolderView.collection.path.indexOf(this.collection.path);
  };

  FolderView.prototype.afterRender = function() {
    FolderView.__super__.afterRender.apply(this, arguments);
    this.ionicView = new ionic.views.ListView({
      el: this.$el[0],
      _handleDrag: function(e) {
        ionic.views.ListView.prototype._handleDrag.apply(this, arguments);
        return e.stopPropagation();
      }
    });
    return this.collection.fetchAdditional();
  };

  FolderView.prototype.appendView = function(view) {
    FolderView.__super__.appendView.apply(this, arguments);
    return view.parent = this;
  };

  FolderView.prototype.displaySlider = function(event) {
    var dX, op,
      _this = this;

    this.ionicView.clearDragEffects();
    op = new ionic.SlideDrag({
      el: this.ionicView.el,
      canSwipe: function() {
        return true;
      }
    });
    op.start({
      target: event.target
    });
    dX = op._currentDrag.startOffsetX === 0 ? 0 - op._currentDrag.buttonsWidth : op._currentDrag.buttonsWidth;
    op.end({
      gesture: {
        deltaX: dX,
        direction: 'right'
      }
    });
    ionic.requestAnimationFrame(function() {
      return _this.ionicView._lastDragOp = op;
    });
    event.preventDefault();
    return event.stopPropagation();
  };

  return FolderView;

})(CollectionView);

});

;require.register("views/folder_line", function(exports, require, module) {
var BaseView, FolderLineView, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = FolderLineView = (function(_super) {
  __extends(FolderLineView, _super);

  function FolderLineView() {
    this.onError = __bind(this.onError, this);
    this.afterOpen = __bind(this.afterOpen, this);
    this.removeFromCache = __bind(this.removeFromCache, this);
    this.addToCache = __bind(this.addToCache, this);
    this.onClick = __bind(this.onClick, this);
    this.updateProgress = __bind(this.updateProgress, this);
    this.hideProgress = __bind(this.hideProgress, this);
    this.displayProgress = __bind(this.displayProgress, this);
    this.setCacheIcon = __bind(this.setCacheIcon, this);
    this.afterRender = __bind(this.afterRender, this);
    this.initialize = __bind(this.initialize, this);    _ref = FolderLineView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  FolderLineView.prototype.tagName = 'a';

  FolderLineView.prototype.template = require('../templates/folder_line');

  FolderLineView.prototype.events = {
    'click .item-content': 'onClick',
    'tap .item-options .download': 'addToCache',
    'tap .item-options .uncache': 'removeFromCache'
  };

  FolderLineView.prototype.className = 'item item-icon-left item-icon-right item-complex';

  FolderLineView.prototype.initialize = function() {
    return this.listenTo(this.model, 'change', this.render);
  };

  FolderLineView.prototype.afterRender = function() {
    return this.$el[0].dataset.folderid = this.model.get('_id');
  };

  FolderLineView.prototype.setCacheIcon = function(klass) {
    var icon, _ref1, _ref2;

    icon = this.$('.cache-indicator');
    icon.removeClass('ion-warning ion-looping ion-ios7-cloud-download-outline');
    icon.removeClass('ion-ios7-download-outline').addClass(klass);
    return (_ref1 = this.parent) != null ? (_ref2 = _ref1.ionicView) != null ? _ref2.clearDragEffects() : void 0 : void 0;
  };

  FolderLineView.prototype.displayProgress = function() {
    this.hideProgress();
    this.progresscontainer = $('<div class="item-progress"></div>').append(this.progressbar = $('<div class="item-progress-bar"></div>'));
    return this.progresscontainer.appendTo(this.$el);
  };

  FolderLineView.prototype.hideProgress = function() {
    var _ref1;

    return (_ref1 = this.progresscontainer) != null ? _ref1.remove() : void 0;
  };

  FolderLineView.prototype.updateProgress = function(percent) {
    var _ref1;

    return (_ref1 = this.progressbar) != null ? _ref1.css('width', (100 * percent) + '%') : void 0;
  };

  FolderLineView.prototype.onClick = function(event) {
    var onload, onprogress, path,
      _this = this;

    if ($(event.target).closest('.cache-indicator').length) {
      return true;
    }
    if (this.model.get('docType') === 'Folder') {
      path = this.model.get('path') + '/' + this.model.get('name');
      return app.router.navigate("#folder" + path, {
        trigger: true
      });
    } else {
      this.displayProgress();
      onprogress = function(done, total) {
        return _this.updateProgress(done / total);
      };
      onload = function(err, url) {
        _this.hideProgress();
        if (err) {
          return _this.onError(err);
        }
        return ExternalFileUtil.openWith(url, '', void 0, _this.afterOpen, _this.onError);
      };
      return app.replicator.getBinary(this.model.attributes, onload, onprogress);
    }
  };

  FolderLineView.prototype.addToCache = function() {
    var after, onprogress,
      _this = this;

    this.setCacheIcon('ion-looping');
    after = function(err) {
      _this.hideProgress();
      if (err) {
        alert(err);
      } else {
        _this.model.set({
          incache: true
        });
      }
      return _this.render();
    };
    this.displayProgress();
    onprogress = function(done, total) {
      return _this.updateProgress(done / total);
    };
    if (this.model.get('docType') === 'Folder') {
      return app.replicator.getBinaryFolder(this.model.attributes, after, onprogress);
    } else {
      return app.replicator.getBinary(this.model.attributes, after);
    }
  };

  FolderLineView.prototype.removeFromCache = function() {
    var after,
      _this = this;

    this.setCacheIcon('ion-looping');
    after = function(err) {
      if (err) {
        alert(err);
      } else {
        _this.model.set({
          incache: false
        });
      }
      return _this.render();
    };
    if (this.model.get('docType') === 'Folder') {
      return app.replicator.removeLocalFolder(this.model.attributes, after);
    } else {
      return app.replicator.removeLocal(this.model.attributes, after);
    }
  };

  FolderLineView.prototype.afterOpen = function() {
    return this.model.set({
      incache: true
    });
  };

  FolderLineView.prototype.onError = function(e) {
    return alert(e);
  };

  return FolderLineView;

})(BaseView);

});

;require.register("views/layout", function(exports, require, module) {
var BaseView, FolderView, Layout, Menu, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

FolderView = require('./folder');

Menu = require('./menu');

module.exports = Layout = (function(_super) {
  __extends(Layout, _super);

  function Layout() {
    this.setBackButton = __bind(this.setBackButton, this);
    this.closeMenu = __bind(this.closeMenu, this);    _ref = Layout.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Layout.prototype.template = require('../templates/layout');

  Layout.prototype.events = function() {
    return {
      'click #btn-menu': 'onMenuButtonClicked'
    };
  };

  Layout.prototype.afterRender = function() {
    this.menu = new Menu();
    this.menu.render();
    this.$el.append(this.menu.$el);
    this.container = this.$('#container');
    this.viewsPlaceholder = this.$('#viewsPlaceholder');
    this.viewsBlock = $('<div class="scroll"></div>');
    this.viewsPlaceholder.append(this.viewsBlock);
    this.backButton = this.container.find('#btn-back');
    this.menuButton = this.container.find('#btn-menu');
    this.ionicContainer = new ionic.views.SideMenuContent({
      el: this.container[0]
    });
    this.ionicMenu = new ionic.views.SideMenu({
      el: this.menu.$el[0],
      width: 270
    });
    this.controller = new ionic.controllers.SideMenuController({
      content: this.ionicContainer,
      left: this.ionicMenu
    });
    return this.ionicScroll = new ionic.views.Scroll({
      el: this.viewsPlaceholder[0]
    });
  };

  Layout.prototype.closeMenu = function() {
    return this.controller.toggleLeft(false);
  };

  Layout.prototype.setBackButton = function(href, icon) {
    this.backButton.attr('href', href);
    this.backButton.removeClass('ion-home ion-ios7-arrow-back');
    return this.backButton.addClass('ion-' + icon);
  };

  Layout.prototype.transitionTo = function(view, type) {
    var $next, currClass, nextClass, transitionend, _ref1,
      _this = this;

    this.closeMenu();
    $next = view.render().$el;
    if (this.currentView instanceof FolderView && view instanceof FolderView) {
      type = this.currentView.isParentOf(view) ? 'left' : 'right';
    } else {
      type = 'none';
    }
    if (type === 'none') {
      if ((_ref1 = this.currentView) != null) {
        _ref1.remove();
      }
      this.viewsBlock.empty().append($next);
      this.ionicScroll.hintResize();
      return this.currentView = view;
    } else {
      nextClass = type === 'left' ? 'sliding-next' : 'sliding-prev';
      currClass = type === 'left' ? 'sliding-prev' : 'sliding-next';
      $next.addClass(nextClass);
      this.viewsBlock.append($next);
      $next.width();
      this.currentView.$el.addClass(currClass);
      $next.removeClass(nextClass);
      transitionend = 'webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend';
      return $next.one(transitionend, function() {
        _this.currentView.remove();
        return _this.currentView = view;
      });
    }
  };

  Layout.prototype.onMenuButtonClicked = function() {
    this.menu.reset();
    return this.controller.toggleLeft();
  };

  return Layout;

})(BaseView);

});

;require.register("views/menu", function(exports, require, module) {
var BaseView, Menu, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = Menu = (function(_super) {
  __extends(Menu, _super);

  function Menu() {
    this.doSearchIfEnter = __bind(this.doSearchIfEnter, this);    _ref = Menu.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Menu.prototype.id = 'menu';

  Menu.prototype.className = 'menu menu-left';

  Menu.prototype.template = require('../templates/menu');

  Menu.prototype.events = {
    'click #refresher': 'refresh',
    'click #btn-search': 'doSearch',
    'click a.item': 'closeMenu',
    'keydown #search-input': 'doSearchIfEnter'
  };

  Menu.prototype.refresh = function() {
    this.$('#refresher i').removeClass('ion-loop').addClass('ion-looping');
    event.stopImmediatePropagation();
    return app.replicator.sync(function(err) {
      var _ref1, _ref2;

      if (err) {
        alert(err);
      }
      if ((_ref1 = app.layout.currentView) != null) {
        if ((_ref2 = _ref1.collection) != null) {
          _ref2.fetch();
        }
      }
      this.$('#refresher i').removeClass('ion-looping').addClass('ion-loop');
      return app.layout.closeMenu();
    });
  };

  Menu.prototype.doSearchIfEnter = function(event) {
    if (event.which === 13) {
      return this.doSearch();
    }
  };

  Menu.prototype.doSearch = function() {
    var val;

    val = $('#search-input').val();
    if (val.length === 0) {
      return true;
    }
    app.layout.closeMenu();
    return app.router.navigate('#search/' + val, {
      trigger: true
    });
  };

  Menu.prototype.reset = function() {
    return this.$('#search-input').val('');
  };

  return Menu;

})(BaseView);

});

;
//@ sourceMappingURL=app.js.map