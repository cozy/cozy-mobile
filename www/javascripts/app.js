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
var Replicator;

Replicator = require('./lib/replicator');

module.exports = {
  initialize: function() {
    var MenuView, Router, e, locales, _ref,
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
    this.backButton = $('#btn-back');
    MenuView = require('./views/menu');
    this.menu = MenuView();
    $('#btn-menu').on('click', function() {
      return _this.menu.reset().toggleLeft();
    });
    if ((_ref = window.cblite) == null) {
      window.cblite = {
        getURL: function(cb) {
          return cb(null, 'http://localhost:5984/');
        }
      };
    }
    this.replicator = new Replicator();
    return this.replicator.init(function(err, config) {
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
      var docs;

      if (err) {
        return options != null ? typeof options.onError === "function" ? options.onError(err) : void 0 : void 0;
      }
      docs = response.rows.map(function(row) {
        var doc, isDoc;

        doc = row.value;
        isDoc = function(entry) {
          return entry.name === doc.binary.file.id;
        };
        if (doc.docType === 'File' && app.replicator.cache.some(isDoc)) {
          doc.incache = true;
        }
        return doc;
      });
      _this.reset(docs);
      return options != null ? typeof options.onSuccess === "function" ? options.onSuccess(_this) : void 0 : void 0;
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
var DBNAME, REGEXP_PROCESS_STATUS, Replicator, basic, deleteEntry, getChildren, getFile, getOrCreateSubFolder, request;

request = require('./request');

basic = require('./basic');

DBNAME = "cozy-files";

REGEXP_PROCESS_STATUS = /Processed (\d+) \/ (\d+) changes/;

module.exports = Replicator = (function() {
  function Replicator() {}

  Replicator.prototype.server = null;

  Replicator.prototype.db = null;

  Replicator.prototype.config = null;

  Replicator.prototype.destroyDB = function(callback) {
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
      return this.downloads.removeRecursively(onSuccess, onError);
    });
  };

  Replicator.prototype.init = function(callback) {
    var _this = this;

    return this.initDownloadFolder(function(err) {
      if (err) {
        return callback(err);
      }
      _this.db = new PouchDB(DBNAME);
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
    var onError, onSuccess,
      _this = this;

    if (window.isBrowserDebugging) {
      this.cache = [];
      return callback(null);
    }
    onError = function(err) {
      return callback(err);
    };
    onSuccess = function(fs) {
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
    return window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, onSuccess, onError);
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
    var _this = this;

    return this.db.replicate.from(this.config.fullRemoteURL, {
      filter: "" + this.config.deviceId + "/filterDocType",
      complete: function(err, result) {
        if (err) {
          return callback(err);
        }
        _this.config.checkpointed = result.last_seq;
        return _this.saveConfig(callback);
      }
    });
  };

  Replicator.prototype.download = function(binary_id, local, callback) {
    var errors, ft, onError, onSuccess, options, url;

    url = encodeURI("" + this.config.fullRemoteURL + "/" + binary_id + "/file");
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
    return ft.download(url, local, onSuccess, onError, false, options);
  };

  Replicator.prototype.getBinary = function(model, callback) {
    var binary_id,
      _this = this;

    binary_id = model.binary.file.id;
    return getOrCreateSubFolder(this.downloads, binary_id, function(err, binfolder) {
      if (err) {
        return callback(err);
      }
      return getFile(binfolder, model.name, function(err, entry) {
        var local;

        if (entry) {
          return callback(null, entry.toURL());
        }
        local = binfolder.toURL() + '/' + model.name;
        return _this.download(binary_id, local, function(err, entry) {
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

;require.register("locales/fr", function(exports, require, module) {
module.exports = {
  "Add": "Ajouter",
  "alarm": "Alarme",
  "event": "Evénement",
  "add the alarm": "Ajouter l'alarme",
  "create alarm": "Création d'une alarme",
  "create event": "Création d'un évènement",
  "edit alarm": "Modification d'une alarme",
  "edit event": "Modification d'un évènement",
  "edit": "Enregistrer",
  "create": "Enregistrer",
  "creation": "Creation",
  "invite": "Inviter",
  "close": "Fermer",
  "delete": "Supprimer",
  "Place": "Lieu",
  "description": "Description",
  "date": "Date",
  "Day": "Jour",
  "Edit": "Modifier",
  "Email": "Email",
  "Import": "Import",
  "Export": "Export",
  "List": "Liste",
  "list": "liste",
  "Calendar": "Calendrier",
  "calendar": "Calendrier",
  "Sync": "Sync",
  "ie: 9:00 important meeting": "exemple: 9:00 appeler Jacque",
  "Month": "Mois",
  "Popup": "Popup",
  "Switch to List": "Basculer en mode List",
  "Switch to Calendar": "Basculer en mode Calendrier",
  "time": "Heure",
  "Today": "Aujourd'hui",
  "What should I remind you ?": "Que dois-je vous rappeler ?",
  "alarm description placeholder": "Que voulez-vous vous rappeler ?",
  "ICalendar importer": "Importateur ICalendar",
  "import your icalendar file": "Importer votre fichier icalendar",
  "confirm import": "Confirmer l'import",
  "cancel": "Annuler",
  "Create": "Créer",
  "Alarms to import": "Alarmes à importer",
  "Events to import": "Evenements à importer",
  "Create Event": "Créer un évènement",
  "From hours:minutes": "De heures:minutes",
  "To hours:minutes+days": "A heures:minutes+jours",
  "Description": "Description",
  "days after": "jours plus tard",
  "days later": "jours plus tard",
  "Week": "Semaine",
  "Alarms": "Alarmes",
  "Display": "Notification",
  "DISPLAY": "Notification",
  "EMAIL": "E-mail",
  "BOTH": "E-mail & Notification",
  "display previous events": "Montrer les évènements précédent",
  "event": "Evenement",
  "alarm": "Alarme",
  "are you sure": "Etes-vous sur ?",
  "advanced": "Détails",
  "enter email": "Entrer l'addresse email",
  "ON": "activée",
  "OFF": "désactivée",
  "recurrence": "Recurrence",
  "recurrence rule": "Règle de recurrence",
  "make reccurent": "Rendre réccurent",
  "repeat every": "Répéter tous les",
  "no recurrence": "Pas de répétition",
  "repeat on": "Répéter les",
  "repeat on date": "Répéter les jours du mois",
  "repeat on weekday": "Répéter le jour de la semaine",
  "repeat until": "Répéter jusqu'au",
  "after": "ou après",
  "repeat": "Répétition",
  "forever": "Pour toujours",
  "occurences": "occasions",
  "every": "tous les",
  "days": "jours",
  "day": "jour",
  "weeks": "semaines",
  "week": "semaines",
  "months": "mois",
  "month": "mois",
  "years": "ans",
  "year": "ans",
  "until": "jusqu'au",
  "for": "pour",
  "on": "le",
  "on the": "le",
  "th": "ème",
  "nd": "ème",
  "rd": "ème",
  "st": "er",
  "last": "dernier",
  "and": "et",
  "times": "fois",
  "weekday": "jours de la semaine",
  "summary": "Titre",
  "place": "Endroit",
  "start": "Début",
  "end": "Fin",
  "tags": "Tags",
  "add tags": "Ajouter des tags",
  "change": "Modifier",
  "change calendar": "Changer le calendrier",
  "save changes": "Enregistrer",
  "save changes and invite guests": "Enregistrer et envoyer les invitations",
  "guests": "Invités",
  "no description": "Le titre est obligatoire",
  "start after end": "La fin est après le début.",
  "invalid start date": "Le début est invalide.",
  "invalid end date": "La fin est invalide.",
  "invalid trigg date": "Le moment est invalide.",
  "invalid action": "L'action est invalide."
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

  File.prototype.sync = function(method, model, options) {
    var progress;

    progress = function(e) {
      return model.trigger('progress', e);
    };
    _.extend(options, {
      xhr: function() {
        var xhr;

        xhr = $.ajaxSettings.xhr();
        if (xhr instanceof window.XMLHttpRequest) {
          xhr.addEventListener('progress', progress, false);
        }
        if (xhr.upload) {
          xhr.upload.addEventListener('progress', progress, false);
        }
        return xhr;
      }
    });
    return Backbone.sync.apply(this, arguments);
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
    var collection,
      _this = this;

    $('#btn-menu, #btn-back').show();
    if (path === null) {
      app.backButton.attr('href', '#folder/').removeClass('ion-ios7-arrow-back').addClass('ion-home');
    } else {
      app.backButton.attr('href', '#folder/' + path.split('/').slice(0, -1)).removeClass('ion-home').addClass('ion-ios7-arrow-back');
    }
    collection = new FolderCollection([], {
      path: path
    });
    return collection.fetch({
      onError: function(err) {
        return alert(err);
      },
      onSuccess: function() {
        return _this.display(new FolderView({
          collection: collection
        }));
      }
    });
  };

  Router.prototype.search = function(query) {
    var collection,
      _this = this;

    $('#btn-menu, #btn-back').show();
    app.backButton.attr('href', '#folder/').removeClass('ion-ios7-arrow-back').addClass('ion-home');
    collection = new FolderCollection([], {
      query: query
    });
    return collection.fetch({
      onError: function(err) {
        return alert(err);
      },
      onSuccess: function() {
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
    var isBack, next, transitionend,
      _this = this;

    if (this.mainView instanceof FolderView && view instanceof FolderView) {
      isBack = this.mainView.isParentOf(view);
      next = view.render().$el.addClass(isBack ? 'sliding-next' : 'sliding-prev');
      $('#mainContent').append(next);
      next.width();
      this.mainView.$el.addClass(isBack ? 'sliding-prev' : 'sliding-next');
      next.removeClass(isBack ? 'sliding-next' : 'sliding-prev');
      transitionend = 'webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend';
      return next.one(transitionend, function() {
        console.log("trend");
        _this.mainView.remove();
        return _this.mainView = view;
      });
    } else {
      console.log("DOH");
      if (this.mainView) {
        this.mainView.remove();
      }
      this.mainView = view.render();
      return $('#mainContent').append(this.mainView.$el);
    }
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
buf.push('</span><input id="input-device" type="text"/></label><button id="btn-save" class="button button-block button-calm">Save</button>');
}
return buf.join("");
};
});

;require.register("templates/folder", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div id="dialog-upload-file" class="modal fade"><div class="modal-dialog"><div class="modal-content"><div class="modal-header"><button type="button" data-dismiss="modal" aria-hidden="true" class="close">×</button><h4 class="modal-title">' + escape((interp = t("upload caption")) == null ? '' : interp) + '</h4></div><div class="modal-body"><fieldset><div class="form-group"><label for="uploader">' + escape((interp = t("upload msg")) == null ? '' : interp) + '</label><input id="uploader" type="file" multiple="multiple" class="form-control"/></div></fieldset></div><div class="modal-footer"><button id="cancel-new-file" type="button" data-dismiss="modal" class="btn btn-link">' + escape((interp = t("upload close")) == null ? '' : interp) + '</button><button id="upload-file-send" type="button" class="btn btn-cozy-contrast">' + escape((interp = t("upload send")) == null ? '' : interp) + '</button></div></div></div></div><div id="dialog-new-folder" class="modal fade"><div class="modal-dialog"><div class="modal-content"><div class="modal-header"><button type="button" data-dismiss="modal" aria-hidden="true" class="close">×</button><h4 class="modal-title">' + escape((interp = t("new folder caption")) == null ? '' : interp) + '</h4></div><div class="modal-body"><fieldset><div class="form-group"><label for="inputName">' + escape((interp = t("new folder msg")) == null ? '' : interp) + '</label><input id="inputName" type="text" class="form-control"/></div><div id="folder-upload-form" class="form-group hide"><br/><p class="text-center">or</p><label for="inputName">' + escape((interp = t("upload folder msg")) == null ? '' : interp) + '</label><input id="folder-uploader" type="file" directory="directory" mozdirectory="mozdirectory" webkitdirectory="webkitdirectory" class="form-control"/></div></fieldset></div><div class="modal-footer"><button id="cancel-new-folder" type="button" data-dismiss="modal" class="btn btn-link">' + escape((interp = t("new folder close")) == null ? '' : interp) + '</button><button id="new-folder-send" type="button" class="btn btn-cozy">' + escape((interp = t("new folder send")) == null ? '' : interp) + '</button></div></div></div></div><div id="affixbar" data-spy="affix" data-offset-top="1"><div class="container"><div class="row"><div class="col-lg-12"><p class="pull-right"><input id="search-box" type="search" class="pull-right"/><div id="upload-buttons" class="pull-right"><a id="button-upload-new-file" class="btn btn-cozy"><img src="images/add-file.png"/></a>&nbsp;<a id="button-new-folder" data-toggle="modal" data-target="#dialog-new-folder" class="btn btn-cozy"><img src="images/add-folder.png"/></a></div></p></div></div></div></div><div class="container"><div class="row content-shadow"><div id="content" class="col-lg-12"><div id="crumbs"></div><div id="loading-indicator"></div><table id="table-items" class="table table-hover"><tbody id="table-items-body"><tr class="table-headers"><td><span>Name</span><a id="down-name" class="btn glyphicon glyphicon-chevron-down"></a><a id="up-name" class="btn glyphicon glyphicon-chevron-up"></a></td><td class="size-column-cell"><span>Size</span><a id="down-size" class="glyphicon glyphicon-chevron-down btn"></a><a id="up-size" class="unactive btn glyphicon glyphicon-chevron-up"></a></td><td class="type-column-cell"><span>Type</span><a id="down-class" class="btn glyphicon glyphicon-chevron-down"></a><a id="up-class" class="glyphicon glyphicon-chevron-up btn unactive"></a></td><td class="date-column-cell"><span>Date</span><a id="down-lastModification" class="btn glyphicon glyphicon-chevron-down"></a><a id="up-lastModification" class="btn glyphicon glyphicon-chevron-up unactive"></a></td></tr></tbody></table><div id="files"></div></div></div></div>');
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
if ( model.incache)
{
buf.push('<i class="icon ion-ios7-download-outline"></i>');
}
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
buf.push('<div class="item item-input-inset"><label class="item-input-wrapper"><input id="search-input" type="text" placeholder="Search"/></label><a id="btn-search" class="button button-icon icon ion-search"></a></div><a href="#folder/" class="item item-icon-left"><i class="icon ion-home"></i>Home</a><a href="#configrun" class="item item-icon-left"><i class="icon ion-wrench"></i>Config</a><a id="refresher" class="item item-icon-left"><i class="icon ion-loop"></i>Refresh</a>');
}
return buf.join("");
};
});

;require.register("views/config", function(exports, require, module) {
var BaseView, ConfigView, showLoader, urlparse, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

showLoader = require('./loader');

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
    return app.replicator.registerRemote(config, function(err) {
      var loader, progressback;

      if (err) {
        return _this.displayError(err.message);
      }
      loader = showLoader("dowloading file structure\n(this may take a while, do not turn off the application)");
      progressback = function(ratio) {
        return loader.setContent('status = ' + 100 * ratio + '%');
      };
      return app.replicator.initialReplication(progressback, function(err) {
        loader.hide();
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
    if (this.error) {
      this.error.remove();
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
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

CollectionView = require('../lib/view_collection');

module.exports = FolderView = (function(_super) {
  __extends(FolderView, _super);

  function FolderView() {
    _ref = FolderView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  FolderView.prototype.className = 'pane';

  FolderView.prototype.itemview = require('./folder_line');

  FolderView.prototype.template = function() {
    return "<div class=\"list\"></div>";
  };

  FolderView.prototype.collectionEl = '.list';

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

  return FolderView;

})(CollectionView);

});

;require.register("views/folder_line", function(exports, require, module) {
var BaseView, ConfigView, showLoader, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

showLoader = require('./loader');

module.exports = ConfigView = (function(_super) {
  __extends(ConfigView, _super);

  function ConfigView() {
    this.onError = __bind(this.onError, this);
    this.afterOpen = __bind(this.afterOpen, this);
    this.onClick = __bind(this.onClick, this);
    this.initialize = __bind(this.initialize, this);    _ref = ConfigView.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  ConfigView.prototype.tagName = 'a';

  ConfigView.prototype.template = require('../templates/folder_line');

  ConfigView.prototype.events = {
    'click': 'onClick'
  };

  ConfigView.prototype.className = 'item item-icon-left item-icon-right';

  ConfigView.prototype.initialize = function() {
    return this.listenTo(this.model, 'change', this.render);
  };

  ConfigView.prototype.onClick = function() {
    var path,
      _this = this;

    if (this.model.get('docType') === 'Folder') {
      path = this.model.get('path') + '/' + this.model.get('name');
      return app.router.navigate("#folder" + path, {
        trigger: true
      });
    } else {
      this.loader = showLoader('downloading binary');
      return app.replicator.getBinary(this.model.attributes, function(err, url) {
        if (err) {
          return _this.onError(err);
        }
        return ExternalFileUtil.openWith(url, '', void 0, _this.afterOpen, _this.onError);
      });
    }
  };

  ConfigView.prototype.afterOpen = function() {
    this.model.set({
      incache: true
    });
    this.loader.hide();
    return this.loader.$el.remove();
  };

  ConfigView.prototype.onError = function(e) {
    this.loader.hide();
    this.loader.$el.remove();
    return alert(e);
  };

  return ConfigView;

})(BaseView);

});

;require.register("views/loader", function(exports, require, module) {
module.exports = function(content) {
  var el, view;

  $('body').append(el = $("<div class=\"loading-backdrop\" class=\"enabled\">\n    <div class=\"loading\">" + content + "</div>\n</div>"));
  view = new ionic.views.Loading({
    el: el[0]
  });
  view.$el = el;
  view.show();
  view.setContent = function(text) {
    return $el.find('.loading').text(text);
  };
  return view;
};

});

;require.register("views/menu", function(exports, require, module) {
module.exports = function() {
  var $menu, content, doSearch, leftMenu, menu;

  $menu = $('#menu-left-list');
  $menu.append(require('../templates/menu')());
  $menu.on('click', '#refresher', function(event) {
    $('#refresher i').removeClass('ion-loop').addClass('ion-looping');
    event.stopImmediatePropagation();
    return app.replicator.sync(function(err) {
      var _ref, _ref1;

      if (err) {
        alert(err);
      }
      if ((_ref = app.router.mainView) != null) {
        if ((_ref1 = _ref.collection) != null) {
          _ref1.fetch();
        }
      }
      $('#refresher i').removeClass('ion-looping').addClass('ion-loop');
      return menu.toggleLeft();
    });
  });
  doSearch = function() {
    var val;

    val = $('#search-input').val();
    if (val.length === 0) {
      return true;
    }
    app.router.navigate('#search/' + val, {
      trigger: true
    });
    return menu.toggleLeft();
  };
  $menu.on('click', '#btn-search', doSearch);
  $menu.on('keydown', '#search-input', function(event) {
    if (event.which === 13) {
      return doSearch();
    }
  });
  $menu.on('click', 'a.item', function() {
    return menu.toggleLeft();
  });
  content = new ionic.views.SideMenuContent({
    el: document.getElementById('content')
  });
  leftMenu = new ionic.views.SideMenu({
    el: $menu[0],
    width: 270
  });
  menu = new ionic.controllers.SideMenuController({
    content: content,
    left: leftMenu
  });
  menu.reset = function() {
    $('#search-input').val('');
    return menu;
  };
  return menu;
};

});

;
//@ sourceMappingURL=app.js.map