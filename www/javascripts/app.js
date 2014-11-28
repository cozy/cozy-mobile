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
    cache[name] = module;
    definition(module.exports, localRequire(name), module);
    return module.exports;
  };

  var require = function(name, loaderPath) {
    var path = expand(name, '.');
    if (loaderPath == null) loaderPath = '/';

    if (has(cache, path)) return cache[path].exports;
    if (has(modules, path)) return initModule(path, modules[path]);

    var dirIndex = expand(path, './index');
    if (has(cache, dirIndex)) return cache[dirIndex].exports;
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

Replicator = require('./replicator/main');

LayoutView = require('./views/layout');

module.exports = {
  initialize: function() {
    window.app = this;
    if (window.isBrowserDebugging) {
      window.navigator = window.navigator || {};
      window.navigator.globalization = window.navigator.globalization || {};
      window.navigator.globalization.getPreferredLanguage = function(callback) {
        return callback({
          value: 'fr-FR'
        });
      };
    }
    return navigator.globalization.getPreferredLanguage((function(_this) {
      return function(properties) {
        var Router, e, locales;
        _this.locale = properties.value.split('-')[0];
        _this.polyglot = new Polyglot();
        locales = (function() {
          try {
            return require('locales/' + this.locale);
          } catch (_error) {
            e = _error;
            return require('locales/en');
          }
        }).call(_this);
        _this.polyglot.extend(locales);
        window.t = _this.polyglot.t.bind(_this.polyglot);
        Router = require('router');
        _this.router = new Router();
        _this.replicator = new Replicator();
        _this.layout = new LayoutView();
        return _this.replicator.init(function(err, config) {
          if (err) {
            console.log(err, err.stack);
            return alert(err.message || err);
          }
          $('body').empty().append(_this.layout.render().$el);
          Backbone.history.start();
          if (config.remote) {
            _this.router.navigate('folder/', {
              trigger: true
            });
            return _this.router.once('collectionfetched', function() {
              app.replicator.startRealtime();
              app.replicator.backup();
              return document.addEventListener("resume", function() {
                console.log("RESUME EVENT");
                if (app.backFromOpen) {
                  return app.backFromOpen = false;
                } else {
                  return app.replicator.backup();
                }
              }, false);
            });
          } else {
            return _this.router.navigate('login', {
              trigger: true
            });
          }
        });
      };
    })(this));
  }
};

});

require.register("collections/files", function(exports, require, module) {
var File, FileAndFolderCollection,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

File = require('../models/file');

module.exports = FileAndFolderCollection = (function(_super) {
  __extends(FileAndFolderCollection, _super);

  function FileAndFolderCollection() {
    return FileAndFolderCollection.__super__.constructor.apply(this, arguments);
  }

  FileAndFolderCollection.prototype.model = File;

  FileAndFolderCollection.cache = {};

  FileAndFolderCollection.prototype.initialize = function(models, options) {
    this.path = options.path;
    this.query = options.query;
    return this.notloaded = true;
  };

  FileAndFolderCollection.prototype.isSearch = function() {
    return this.path === void 0;
  };

  FileAndFolderCollection.prototype.comparator = function(file1, file2) {
    if (file1.get('docType').toLowerCase() === 'folder' && file2.get('docType').toLowerCase() === 'file') {
      return -1;
    } else if (file2.get('docType').toLowerCase() === 'folder' && file1.get('docType').toLowerCase() === 'file') {
      return 1;
    } else if (file1.get('name').toLowerCase() < file2.get('name').toLowerCase()) {
      return -1;
    } else {
      return 1;
    }
  };

  FileAndFolderCollection.prototype.search = function(callback) {
    var params;
    params = {
      query: this.query,
      fields: ['name'],
      include_docs: true
    };
    return app.replicator.db.search(params, (function(_this) {
      return function(err, items) {
        return _this.slowReset(items, function(err) {
          _this.notloaded = false;
          return callback(err);
        });
      };
    })(this));
  };

  FileAndFolderCollection.prototype.fetch = function(_callback) {
    var cacheKey, callback, items;
    if (_callback == null) {
      _callback = function() {};
    }
    callback = (function(_this) {
      return function(err) {
        _this.notloaded = false;
        _this.trigger('sync');
        return _callback(err);
      };
    })(this);
    cacheKey = this.path === null ? '' : this.path;
    if (cacheKey in FileAndFolderCollection.cache) {
      items = FileAndFolderCollection.cache[cacheKey];
      return this.slowReset(items, (function(_this) {
        return function(err) {
          if (!err) {
            _this.fetchAdditional();
          }
          return callback(err);
        };
      })(this));
    }
    console.log("CACHE MISS " + cacheKey);
    return this._fetch(this.path, (function(_this) {
      return function(err, items) {
        if (err) {
          return callback(err);
        }
        return _this.slowReset(items, function(err) {
          if (!err) {
            _this.fetchAdditional();
          }
          return callback(err);
        });
      };
    })(this));
  };

  FileAndFolderCollection.prototype._fetch = function(path, callback) {
    var params;
    params = {
      startkey: path ? ['/' + path] : [''],
      endkey: path ? ['/' + path, {}] : ['', {}],
      include_docs: true
    };
    return app.replicator.db.query('FilesAndFolder', params, callback);
  };

  FileAndFolderCollection.prototype.slowReset = function(results, callback) {
    var i, models, nonBlockingAdd;
    models = results.rows.map(function(row) {
      var binary_id, doc, _ref, _ref1;
      doc = row.doc;
      if (binary_id = (_ref = doc.binary) != null ? (_ref1 = _ref.file) != null ? _ref1.id : void 0 : void 0) {
        doc.incache = app.replicator.fileInFileSystem(doc);
        doc.version = app.replicator.fileVersion(doc);
      }
      return doc;
    });
    this.reset(models.slice(0, 10));
    i = 0;
    return (nonBlockingAdd = (function(_this) {
      return function() {
        if (i * 10 > models.length) {
          _this.nextAdd = null;
          return callback(null);
        }
        i++;
        _this.add(models.slice(i * 10, (i + 1) * 10));
        return _this.nextAdd = setTimeout(nonBlockingAdd, 10);
      };
    })(this))();
  };

  FileAndFolderCollection.prototype.remove = function() {
    FileAndFolderCollection.__super__.remove.apply(this, arguments);
    return this.clearTimeout(this.nextAdd);
  };

  FileAndFolderCollection.prototype.cancelFetchAdditional = function() {
    return this.cancelled = true;
  };

  FileAndFolderCollection.prototype.fetchAdditional = function() {
    var toBeCached;
    FileAndFolderCollection.cache = {};
    toBeCached = this.filter(function(model) {
      var _ref;
      return ((_ref = model.get('docType')) != null ? _ref.toLowerCase() : void 0) === 'folder';
    });
    return async.eachSeries(toBeCached, (function(_this) {
      return function(folder, cb) {
        var path;
        if (_this.cancelled) {
          return cb(new Error('cancelled'));
        }
        path = folder.wholePath();
        return _this._fetch(path, function(err, items) {
          if (this.cancelled) {
            return cb(new Error('cancelled'));
          }
          if (!err) {
            FileAndFolderCollection.cache[path] = items;
          }
          return app.replicator.folderInFileSystem(path, function(err, incache) {
            if (this.cancelled) {
              return cb(new Error('cancelled'));
            }
            if (err) {
              console.log(err);
            }
            folder.set('incache', incache);
            return setTimeout(cb, 10);
          });
        });
      };
    })(this), (function(_this) {
      return function(err) {
        var path;
        if (_this.cancelled) {
          return;
        }
        if (err) {
          console.log(err);
        }
        path = (_this.path || '').split('/').slice(0, -1).join('/');
        return _this._fetch(path, function(err, items) {
          if (_this.cancelled) {
            return;
          }
          if (!err) {
            FileAndFolderCollection.cache[path] = items;
          }
          return _this.trigger('fullsync');
        });
      };
    })(this));
  };

  return FileAndFolderCollection;

})(Backbone.Collection);

});

require.register("initialize", function(exports, require, module) {
var app;

app = require('application');

document.addEventListener('deviceready', function() {
  return app.initialize();
});

});

require.register("lib/base_view", function(exports, require, module) {
var BaseView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

module.exports = BaseView = (function(_super) {
  __extends(BaseView, _super);

  function BaseView() {
    return BaseView.__super__.constructor.apply(this, arguments);
  }

  BaseView.prototype.template = function() {};

  BaseView.prototype.initialize = function() {};

  BaseView.prototype.getRenderData = function() {
    var _ref;
    return {
      model: (_ref = this.model) != null ? _ref.toJSON() : void 0
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

require.register("lib/basic", function(exports, require, module) {
var b64, b64_enc, basic;

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

module.exports = basic = function(auth) {
  return 'Basic ' + b64_enc(auth.username + ':' + auth.password);
};

});

require.register("lib/device_status", function(exports, require, module) {
var battery, callbackWaiting, callbacks, initialized, readyForSync, readyForSyncMsg, update;

callbacks = [];

initialized = false;

readyForSync = null;

readyForSyncMsg = "";

battery = null;

callbackWaiting = function(err, ready, msg) {
  var callback, _i, _len;
  readyForSync = ready;
  readyForSyncMsg = msg;
  for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
    callback = callbacks[_i];
    callback(err, ready, msg);
  }
  return callbacks = [];
};

update = function() {
  if (battery == null) {
    return;
  }
  if (!(battery.level > 20 || battery.isPlugged)) {
    return callbackWaiting(null, false, 'no battery');
  }
  if (app.replicator.config.get('syncOnWifi') && !navigator.connection.type === Connection.WIFI) {
    return callbackWaiting(null, false, 'no wifi');
  }
  return callbackWaiting(null, true);
};

module.exports.checkReadyForSync = function(callback) {
  console.log("check ready for sync");
  if (readyForSync != null) {
    callback(null, readyForSync, readyForSyncMsg);
  } else if (window.isBrowserDebugging) {
    callback(null, true);
  } else {
    callbacks.push(callback);
  }
  if (!initialized) {
    window.addEventListener('batterystatus', (function(_this) {
      return function(newStatus) {
        battery = newStatus;
        return update();
      };
    })(this), false);
    app.replicator.config.on('change:syncOnWifi', update);
    return initialized = true;
  }
};

});

require.register("lib/request", function(exports, require, module) {
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

require.register("lib/view_collection", function(exports, require, module) {
var BaseView, ViewCollection,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('lib/base_view');

module.exports = ViewCollection = (function(_super) {
  __extends(ViewCollection, _super);

  function ViewCollection() {
    this.removeItem = __bind(this.removeItem, this);
    this.addItem = __bind(this.addItem, this);
    return ViewCollection.__super__.constructor.apply(this, arguments);
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
    var idx, modelAfter, viewAfter;
    idx = this.collection.indexOf(view.model);
    modelAfter = this.collection.at(idx + 1);
    if (!modelAfter) {
      return this.$collectionEl.append(view.el);
    }
    viewAfter = this.views[modelAfter.cid];
    if (viewAfter) {
      return viewAfter.$el.before(view.el);
    } else {
      return this.$collectionEl.append(view.el);
    }
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
    var id, view, _ref;
    _ref = this.views;
    for (id in _ref) {
      view = _ref[id];
      view.$el.detach();
    }
    return ViewCollection.__super__.render.apply(this, arguments);
  };

  ViewCollection.prototype.afterRender = function() {
    var id, view, _ref;
    if (!this.$collectionEl) {
      this.$collectionEl = this.$(this.collectionEl);
    }
    _ref = this.views;
    for (id in _ref) {
      view = _ref[id];
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
    var id, view, _ref;
    _ref = this.views;
    for (id in _ref) {
      view = _ref[id];
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

require.register("locales/en", function(exports, require, module) {
module.exports = {
  "app name": "Cozy mobile",
  "cozy url": "Cozy's domain",
  "cozy password": "Cozy's password",
  "device name": "Name this device",
  "search": "search",
  "config": "Config",
  "never": "Never",
  "phone2cozy title": "Phone to Cozy backup",
  "contacts sync label": "Backup contacts",
  "images sync label": "Backup images",
  "wifi sync label": "Backup on Wifi only",
  "home": "Home",
  "about": "About",
  "last sync": "Last sync was : ",
  "last backup": "Last was : ",
  "reset title": "Reset",
  "reset action": "Reset",
  "retry synchro": "Synchro",
  "synchro warning": "This start a replication from the beginning. It can take long time.",
  "reset warning": "This will erase all cozy-generated data on your phone.",
  "pull to sync": "Pull to sync",
  "syncing": "Syncing",
  "contacts_scan": "Scanning contacts for changes",
  "contacts_sync": "Syncing contacts",
  "pictures_sync": "Syncing pictures",
  "synchronized with": "Synchronized with ",
  "this folder is empty": "This folder is empty.",
  "no results": "No results",
  "loading": "Loading",
  "remove local": "Remove local",
  "download": "Download",
  "sync": "Refresh",
  "backup": "Backup",
  "save": "Save",
  "done": "Done",
  "confirm message": "Are you sure?",
  "replication complete": "Replication complete",
  "no activity found": "No application on phone for this kind of file.",
  "not enough space": "Not enough disk space, remove some files from cache.",
  "no battery": "Not enough battery, Backup cancelled.",
  "no wifi": "No Wifi, Backup cancelled.",
  "next": "Next",
  "back": "Back",
  "connection failure": "Connection failure",
  "setup 1/3": "Setup 1/3",
  "password placeholder": "your password",
  "authenticating...": "Authenticating...",
  "setup 2/3": "Setup 2/3",
  "device name explanation": "Choose a display name for this device so you can easily manage it from your Cozy.",
  "device name placeholder": "my-phone",
  "registering...": "Registering...",
  "setup 3/3": "Setup 3/3",
  "setup end": "End of setting",
  "wait message device": "Device configuration...",
  "wait message cozy": "Browser files stored in your cozy ...",
  "wait message": "Please wait while the tree is being downloaded. It can take several minutes...%{progress}%",
  "wait message display": "Files preparation...",
  "ready message": "The application is ready to be used!",
  "waiting...": "Waiting...",
  "filesystem bug error": "File system bug error. Try to restart your phone.",
  "end": "End"
};

});

require.register("locales/fr", function(exports, require, module) {
module.exports = {
  "app name": "Cozy mobile",
  "cozy url": "Adresse Cozy",
  "cozy password": "Mot de passe",
  "device name": "Nom de l'appareil",
  "search": "Recherche",
  "config": "Configuration",
  "never": "Jamais",
  "phone2cozy title": "Sauvegarde du téléphone",
  "contacts sync label": "Sauvegarde des contacts",
  "images sync label": "Sauvegarde des images du téléphone",
  "wifi sync label": "Sauvegarde uniquement en Wifi",
  "home": "Accueil",
  "about": "À propos",
  "last sync": "Dernière synchro : ",
  "last backup": "Derniere sauvegarde : ",
  "reset title": "Remise à zéro",
  "reset action": "R.à.Z",
  "retry synchro": "Sync",
  "synchro warning": "Cela relancera une synchronisation depuis le début. Cela peut prendre du temps.",
  "reset warning": "Cela supprimera toutes les données cozy sur votre mobile (dont votre device).",
  "pull to sync": "Tirer pour synchroniser",
  "syncing": "En cours de synchronisation",
  "contacts_scan": "Extraction des contacts",
  "contacts_sync": "Synchronisation des contacts",
  "pictures_sync": "Synchronisation des images",
  "synchronized with": "Synchronisé avec ",
  "this folder is empty": "Ce dossier est vide.",
  "no results": "Pas de résultats",
  "loading": "Chargement",
  "remove local": "Supprimer du tél.",
  "download": "Télécharger",
  "sync": "Rafraîchir",
  "backup": "Sauvegarder",
  "save": "Sauvegarder",
  "done": "Fait",
  "confirm message": "Êtes-vous sûr ?",
  "replication complete": "Réplication complétée",
  "no activity found": "Aucune application n'a été trouvé sur ce téléphone pour ce type de fichier.",
  "not enough space": "Il n'y a pas suffisament d'espace disque sur votre mobile.",
  "no battery": "La sauvegarde n'aura pas lieu car vous n'avez pas assez de batterie.",
  "no wifi": "La sauvegarde n'aura pas lieu car vous n'êtes pas en wifi.",
  "next": "Suivant",
  "back": "Retour",
  "connection failure": "Echec de la connexion",
  "setup 1/3": "Configuration 1/3",
  "password placeholder": "votre mot de passe",
  "authenticating...": "Vérification des identifiants...",
  "setup 2/3": "Configuration 2/3",
  "device name explanation": "Choisissez un nom d'usage pour ce périphérique pour pouvoir le gérer facilement depuis votre Cozy.",
  "device name placeholder": "mon-telephone",
  "registering...": "Enregistrement...",
  "setup 3/3": "Configuration 3/3",
  "setup end": "Fin de la configuration",
  "wait message device": "Enregistrement du device...",
  "wait message cozy": "Parcours des fichiers présents dans votre cozy. Cela peut prendre plusieurs minutes...",
  "wait message": "Merci de patienter pendant le téléchargement de la liste des fichiers.\nCela peut prendre plusieurs minutes...\n           %{progress}%",
  "wait message display": "Préparation des fichiers...",
  "ready message": "L'application est prête à être utilisée !",
  "waiting...": "En attente...",
  "filesystem bug error": "Erreur dans le système de fichier. Essayez de redémarrer votre téléphone",
  "end": "Fin"
};

});

require.register("models/file", function(exports, require, module) {
var File,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

module.exports = File = (function(_super) {
  __extends(File, _super);

  function File() {
    return File.__super__.constructor.apply(this, arguments);
  }

  File.prototype.idAttribute = "_id";

  File.prototype.defaults = function() {
    return {
      incache: 'loading',
      version: false
    };
  };

  File.prototype.initialize = function() {
    return this.isDeviceFolder = this.isFolder() && this.wholePath() === app.replicator.config.get('deviceName');
  };

  File.prototype.isFolder = function() {
    var _ref;
    return ((_ref = this.get('docType')) != null ? _ref.toLowerCase() : void 0) === 'folder';
  };

  File.prototype.wholePath = function() {
    var name, path;
    name = this.get('name');
    if (path = this.get('path')) {
      return "" + (path.slice(1)) + "/" + name;
    } else {
      return name;
    }
  };

  return File;

})(Backbone.Model);

});

require.register("replicator/filesystem", function(exports, require, module) {
var DOWNLOADS_FOLDER, basic, fs, getFileSystem, readable, __chromeSafe;

DOWNLOADS_FOLDER = 'cozy-downloads';

basic = require('../lib/basic');

module.exports = fs = {};

getFileSystem = function(callback) {
  var onError, onSuccess;
  onSuccess = function(fs) {
    return callback(null, fs);
  };
  onError = function(err) {
    return callback(err);
  };
  if (window.isBrowserDebugging) {
    __chromeSafe();
  }
  return window.requestFileSystem(LocalFileSystem.PERSISTENT, 0, onSuccess, onError);
};

readable = function(err) {
  var code, name;
  for (name in FileError) {
    code = FileError[name];
    if (code === err.code) {
      return new Error(name.replace('_ERR', '').replace('_', ' '));
    }
  }
  return new Error(JSON.stringify(err));
};

module.exports.initialize = function(callback) {
  return getFileSystem((function(_this) {
    return function(err, filesystem) {
      if (err) {
        return callback(readable(err));
      }
      window.FileTransfer.fs = filesystem;
      return fs.getOrCreateSubFolder(filesystem.root, DOWNLOADS_FOLDER, function(err, downloads) {
        if (err) {
          return callback(readable(err));
        }
        downloads.getFile('.nomedia', {
          create: true,
          exclusive: false
        }, function() {
          return console.log("NOMEDIA FILE CREATED");
        }, function() {
          return console.log("NOMEDIA FILE NOT CREATED");
        });
        return fs.getChildren(downloads, function(err, children) {
          if (err) {
            return callback(readable(err));
          }
          return callback(null, downloads, children);
        });
      });
    };
  })(this));
};

module.exports["delete"] = function(entry, callback) {
  var onError, onSuccess;
  onSuccess = function() {
    return callback(null);
  };
  onError = function(err) {
    return callback(err);
  };
  return entry.remove(onSuccess, onError);
};

module.exports.getFile = function(parent, name, callback) {
  var onError, onSuccess;
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return parent.getFile(name, null, onSuccess, onError);
};

module.exports.getDirectory = function(parent, name, callback) {
  var onError, onSuccess;
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return parent.getDirectory(name, {}, onSuccess, onError);
};

module.exports.getOrCreateSubFolder = function(parent, name, callback) {
  var onError, onSuccess;
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return parent.getDirectory(name, {
    create: true
  }, onSuccess, function(err) {
    if (err.code !== FileError.PATH_EXISTS_ERR) {
      return callback(err);
    }
    return parent.getDirectory(name, {}, onSuccess, function(err) {
      if (err.code !== FileError.NOT_FOUND_ERR) {
        return callback(err);
      }
      return callback(new Error(t('filesystem bug error')));
    });
  });
};

module.exports.getChildren = function(directory, callback) {
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

module.exports.rmrf = function(directory, callback) {
  var onError, onSuccess;
  onError = function(err) {
    return callback(err);
  };
  onSuccess = function() {
    return callback(null);
  };
  return directory.removeRecursively(onSuccess, onError);
};

module.exports.freeSpace = function(callback) {
  var onError, onSuccess;
  onError = function(err) {
    return callback(err);
  };
  onSuccess = function() {
    return callback(null);
  };
  return cordova.exec(onSuccess, onError, 'File', 'getFreeDiskSpace', []);
};

module.exports.entryFromPath = function(path, callback) {
  var onError, onSuccess;
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return resolveLocalFileSystemURL('file://' + path, onSuccess, onError);
};

module.exports.fileFromEntry = function(entry, callback) {
  var onError, onSuccess;
  onSuccess = function(file) {
    return callback(null, file);
  };
  onError = function(err) {
    return callback(err);
  };
  return entry.file(onSuccess, onError);
};

module.exports.contentFromFile = function(file, callback) {
  var reader;
  reader = new FileReader();
  reader.onerror = callback;
  reader.onload = function() {
    return callback(null, reader.result);
  };
  return reader.readAsArrayBuffer(file);
};

module.exports.getFileFromPath = function(path, callback) {
  return fs.entryFromPath(path, function(err, entry) {
    if (err) {
      return callback(err);
    }
    return fs.fileFromEntry(entry, callback);
  });
};

module.exports.metadataFromEntry = function(entry, callback) {
  var onError, onSuccess;
  onSuccess = function(file) {
    return callback(null, file);
  };
  onError = function(err) {
    return callback(err);
  };
  return entry.getMetadata(onSuccess, onError);
};

module.exports.download = function(options, progressback, callback) {
  var auth, errors, ft, headers, onError, onSuccess, path, url;
  errors = ['An error happened (UNKNOWN)', 'An error happened (NOT FOUND)', 'An error happened (INVALID URL)', 'This file isnt available offline', 'ABORTED'];
  options = (url = options.url, path = options.path, auth = options.auth, options);
  url = encodeURI(url);
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(new Error(errors[err.code]));
  };
  ft = new FileTransfer();
  ft.onprogress = function(e) {
    if (e.lengthComputable) {
      return progressback(e.loaded, e.total);
    } else {
      return progressback(3, 10);
    }
  };
  headers = {
    Authorization: basic(auth)
  };
  return ft.download(url, path, onSuccess, onError, true, {
    headers: headers
  });
};

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
  window.ImagesBrowser = {
    getImageList: function() {
      return [];
    }
  };
  return window.FileTransfer = FileTransfer = (function() {
    function FileTransfer() {}

    FileTransfer.prototype.download = function(url, local, onSuccess, onError, _, options) {
      var key, value, xhr, _ref;
      xhr = new XMLHttpRequest();
      xhr.open('GET', url, true);
      xhr.overrideMimeType('text/plain; charset=x-user-defined');
      xhr.responseType = "arraybuffer";
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

});

require.register("replicator/main", function(exports, require, module) {
var DBCONTACTS, DBNAME, DBOPTIONS, DBPHOTOS, Replicator, ReplicatorConfig, fs, makeDesignDocs, request,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

request = require('../lib/request');

fs = require('./filesystem');

makeDesignDocs = require('./replicator_mapreduce');

ReplicatorConfig = require('./replicator_config');

DBNAME = "cozy-files.db";

DBCONTACTS = "cozy-contacts.db";

DBPHOTOS = "cozy-photos.db";

DBOPTIONS = window.isBrowserDebugging ? {} : {
  adapter: 'websql'
};

module.exports = Replicator = (function(_super) {
  var realtimeBackupCoef;

  __extends(Replicator, _super);

  function Replicator() {
    this.startRealtime = __bind(this.startRealtime, this);
    this.folderInFileSystem = __bind(this.folderInFileSystem, this);
    this.fileVersion = __bind(this.fileVersion, this);
    this.fileInFileSystem = __bind(this.fileInFileSystem, this);
    return Replicator.__super__.constructor.apply(this, arguments);
  }

  Replicator.prototype.db = null;

  Replicator.prototype.config = null;

  _.extend(Replicator.prototype, require('./replicator_backups'));

  Replicator.prototype.defaults = function() {
    return {
      inSync: false,
      inBackup: false
    };
  };

  Replicator.prototype.destroyDB = function(callback) {
    return this.db.destroy((function(_this) {
      return function(err) {
        if (err) {
          return callback(err);
        }
        return _this.contactsDB.destroy(function(err) {
          if (err) {
            return callback(err);
          }
          return _this.photosDB.destroy(function(err) {
            if (err) {
              return callback(err);
            }
            return fs.rmrf(_this.downloads, callback);
          });
        });
      };
    })(this));
  };

  Replicator.prototype.resetSynchro = function(callback) {
    this.set('inSync', true);
    return this._sync(true, (function(_this) {
      return function(err) {
        _this.set('inSync', false);
        return callback(err);
      };
    })(this));
  };

  Replicator.prototype.init = function(callback) {
    return fs.initialize((function(_this) {
      return function(err, downloads, cache) {
        console.log("err1");
        console.log(err);
        if (err) {
          return callback(err);
        }
        _this.downloads = downloads;
        _this.cache = cache;
        _this.db = new PouchDB(DBNAME, DBOPTIONS);
        _this.contactsDB = new PouchDB(DBCONTACTS, DBOPTIONS);
        _this.photosDB = new PouchDB(DBPHOTOS, DBOPTIONS);
        return makeDesignDocs(_this.db, _this.contactsDB, _this.photosDB, function(err) {
          console.log('err2');
          console.log(err);
          if (err) {
            return callback(err);
          }
          _this.config = new ReplicatorConfig(_this);
          return _this.config.fetch(callback);
        });
      };
    })(this));
  };

  Replicator.prototype.getDbFilesOfFolder = function(folder, callback) {
    var options, path;
    path = folder.path + '/' + folder.name;
    options = {
      include_docs: true,
      startkey: path,
      endkey: path + '\uffff'
    };
    return this.db.query('FilesAndFolder', options, function(err, results) {
      var docs, files;
      if (err) {
        return callback(err);
      }
      docs = results.rows.map(function(row) {
        return row.doc;
      });
      files = docs.filter(function(doc) {
        var _ref;
        return ((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file';
      });
      return callback(null, files);
    });
  };

  Replicator.prototype.registerRemote = function(config, callback) {
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
    }, (function(_this) {
      return function(err, response, body) {
        if (err) {
          return callback(err);
        } else if (response.statusCode === 401 && response.reason) {
          return callback(new Error('cozy need patch'));
        } else if (response.statusCode === 401) {
          return callback(new Error('wrong password'));
        } else if (response.statusCode === 400) {
          return callback(new Error('device name already exist'));
        } else {
          _.extend(config, {
            password: body.password,
            deviceId: body.id,
            auth: {
              username: config.deviceName,
              password: body.password
            },
            fullRemoteURL: ("https://" + config.deviceName + ":" + body.password) + ("@" + config.cozyURL + "/cozy")
          });
          return _this.config.save(config, callback);
        }
      };
    })(this));
  };

  Replicator.prototype.checkCredentials = function(config, callback) {
    return request.post({
      uri: "https://" + config.cozyURL + "/login",
      json: {
        username: 'owner',
        password: config.password
      }
    }, function(err, response, body) {
      var error;
      if ((response != null ? response.statusCode : void 0) !== 200) {
        error = (err != null ? err.message : void 0) || body.error || body.message;
      } else {
        error = null;
      }
      return callback(error);
    });
  };

  Replicator.prototype.updateIndex = function(callback) {
    return this.db.search({
      build: true,
      fields: ['name']
    }, (function(_this) {
      return function(err) {
        console.log("INDEX BUILT");
        if (err) {
          console.log(err);
        }
        return _this.db.query('FilesAndFolder', {}, function() {
          return _this.db.query('LocalPath', {}, function() {
            return callback(null);
          });
        });
      };
    })(this));
  };

  Replicator.prototype.initialReplication = function(callback) {
    this.set('initialReplicationRunning', -2);
    return async.series([
      (function(_this) {
        return function(cb) {
          return _this.config.save({
            checkpointed: 0
          }, cb);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.set('initialReplicationRunning', -1 / 10) && cb(null);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.sync(cb, true);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.set('initialReplicationRunning', 9 / 10) && cb(null);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.db.query('FilesAndFolder', {}, cb);
        };
      })(this)
    ], (function(_this) {
      return function(err) {
        console.log("end of inital replication " + (Date.now()));
        _this.set('initialReplicationRunning', 1);
        callback(err);
        return _this.updateIndex(function() {
          return console.log("Index built");
        });
      };
    })(this));
  };

  Replicator.prototype.fileInFileSystem = function(file) {
    return this.cache.some(function(entry) {
      return entry.name.indexOf(file.binary.file.id) !== -1;
    });
  };

  Replicator.prototype.fileVersion = function(file) {
    return this.cache.some(function(entry) {
      return entry.name === file.binary.file.id + '-' + file.binary.file.rev;
    });
  };

  Replicator.prototype.folderInFileSystem = function(path, callback) {
    var fsCacheFolder, options;
    options = {
      startkey: path,
      endkey: path + '\uffff'
    };
    fsCacheFolder = this.cache.map(function(entry) {
      return entry.name;
    });
    return this.db.query('PathToBinary', options, function(err, results) {
      if (err) {
        return callback(err);
      }
      if (results.rows.length === 0) {
        return callback(null, null);
      }
      return callback(null, _.every(results.rows, function(row) {
        var _ref;
        return _ref = row.value, __indexOf.call(fsCacheFolder, _ref) >= 0;
      }));
    });
  };

  Replicator.prototype.getBinary = function(model, progressback, callback) {
    var binary_id, binary_rev;
    binary_id = model.binary.file.id;
    binary_rev = model.binary.file.rev;
    return fs.getOrCreateSubFolder(this.downloads, binary_id + '-' + binary_rev, (function(_this) {
      return function(err, binfolder) {
        if (err && err.code !== FileError.PATH_EXISTS_ERR) {
          return callback(err);
        }
        if (!model.name) {
          return callback(new Error('no model name :' + JSON.stringify(model)));
        }
        return fs.getFile(binfolder, model.name, function(err, entry) {
          var options;
          if (entry) {
            return callback(null, entry.toURL());
          }
          options = _this.config.makeUrl("/" + binary_id + "/file");
          options.path = binfolder.toURL() + '/' + model.name;
          return fs.download(options, progressback, function(err, entry) {
            var found;
            if (((err != null ? err.message : void 0) != null) && err.message === "This file isnt available offline" && _this.fileInFileSystem(model)) {
              found = false;
              _this.cache.some(function(entry) {
                if (entry.name.indexOf(binary_id) !== -1) {
                  found = true;
                  console.log(entry);
                  console.log(entry.toURL());
                  return callback(null, entry.toURL() + '/' + model.name);
                }
              });
              if (!found) {
                return callback(err);
              }
            } else if (err) {
              return fs["delete"](binfolder, function(delerr) {
                return callback(err);
              });
            } else {
              _this.cache.push(binfolder);
              console.log(entry.toURL());
              callback(null, entry.toURL());
              return _this.removeAllLocal(binary_id, binary_rev);
            }
          });
        });
      };
    })(this));
  };

  Replicator.prototype.getBinaryFolder = function(folder, progressback, callback) {
    return this.getDbFilesOfFolder(folder, (function(_this) {
      return function(err, files) {
        var totalSize;
        if (err) {
          return callback(err);
        }
        totalSize = files.reduce((function(sum, file) {
          return sum + file.size;
        }), 0);
        return fs.freeSpace(function(err, available) {
          var progressHandlers, reportProgress;
          if (err) {
            return callback(err);
          }
          if (totalSize > available * 1024) {
            alert(t('not enough space'));
            return callback(null);
          } else {
            progressHandlers = {};
            reportProgress = function(id, done, total) {
              var key, status;
              progressHandlers[id] = [done, total];
              total = done = 0;
              for (key in progressHandlers) {
                status = progressHandlers[key];
                done += status[0];
                total += status[1];
              }
              return progressback(done, total);
            };
            return async.eachLimit(files, 5, function(file, cb) {
              var pb;
              console.log("DOWNLOAD " + file.name);
              pb = reportProgress.bind(null, file._id);
              return _this.getBinary(file, pb, cb);
            }, callback);
          }
        });
      };
    })(this));
  };

  Replicator.prototype.removeAllLocal = function(id, rev) {
    return this.cache.some((function(_this) {
      return function(entry) {
        if (entry.name.indexOf(id) !== -1 && entry.name !== id + '-' + rev) {
          return fs.getDirectory(_this.downloads, entry.name, function(err, binfolder) {
            if (err) {
              return callback(err);
            }
            return fs.rmrf(binfolder, function(err) {
              var currentEntry, index, _i, _len, _ref, _results;
              _ref = _this.cache;
              _results = [];
              for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
                currentEntry = _ref[index];
                if (!(currentEntry.name === entry.name)) {
                  continue;
                }
                _this.cache.splice(index, 1);
                break;
              }
              return _results;
            });
          });
        }
      };
    })(this));
  };

  Replicator.prototype.removeLocal = function(model, callback) {
    var binary_id, binary_rev;
    binary_id = model.binary.file.id;
    binary_rev = model.binary.file.rev;
    console.log("REMOVE LOCAL");
    console.log(binary_id);
    return fs.getDirectory(this.downloads, binary_id + '-' + binary_rev, (function(_this) {
      return function(err, binfolder) {
        if (err) {
          return callback(err);
        }
        return fs.rmrf(binfolder, function(err) {
          var entry, index, _i, _len, _ref;
          _ref = _this.cache;
          for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
            entry = _ref[index];
            if (!(entry.name === binary_id + '-' + binary_rev)) {
              continue;
            }
            _this.cache.splice(index, 1);
            break;
          }
          return callback(null);
        });
      };
    })(this));
  };

  Replicator.prototype.removeLocalFolder = function(folder, callback) {
    return this.getDbFilesOfFolder(folder, (function(_this) {
      return function(err, files) {
        if (err) {
          return callback(err);
        }
        return async.eachSeries(files, function(file, cb) {
          return _this.removeLocal(file, cb);
        }, callback);
      };
    })(this));
  };

  Replicator.prototype.sync = function(callback, force) {
    if (force == null) {
      force = false;
    }
    if (this.get('inSync')) {
      return callback(null);
    }
    console.log("SYNC CALLED");
    this.set('inSync', true);
    return this._sync(force, (function(_this) {
      return function(err) {
        _this.set('inSync', false);
        return callback(err);
      };
    })(this));
  };

  Replicator.prototype._sync = function(force, callback) {
    var checkpoint, options, replication, total_count, _ref;
    console.log("BEGIN SYNC");
    total_count = 0;
    if ((_ref = this.liveReplication) != null) {
      _ref.cancel();
    }
    if (!force) {
      checkpoint = this.config.get('checkpointed');
    } else {
      checkpoint = 0;
      options = this.config.makeUrl("/_design/file/_view/all/");
      request.get(options, (function(_this) {
        return function(err, res, files) {
          options = _this.config.makeUrl("/_design/folder/_view/all/");
          return request.get(options, function(err, res, folders) {
            total_count = files.total_rows + folders.total_rows;
            return console.log("TOTAL DOCUMENTS : " + total_count);
          });
        };
      })(this));
    }
    replication = this.db.replicate.from(this.config.remote, {
      batch_size: 5,
      batches_limit: 1,
      filter: function(doc) {
        return doc.docType === 'Folder' || doc.docType === 'File';
      },
      live: false,
      since: checkpoint
    });
    replication.on('change', (function(_this) {
      return function(change) {
        if (force) {
          return _this.db.info(function(err, info) {
            var progress;
            console.log("LOCAL DOCUMENTS : " + (info.doc_count - 4) + " / " + total_count);
            progress = (9 / 10) * ((info.doc_count - 4) / total_count);
            return _this.set('initialReplicationRunning', progress);
          });
        }
      };
    })(this));
    replication.once('error', (function(_this) {
      return function(err) {
        var _ref1;
        console.log("REPLICATOR ERRROR " + (JSON.stringify(err)) + " " + err.stack);
        if (((err != null ? (_ref1 = err.result) != null ? _ref1.status : void 0 : void 0) != null) && err.result.status === 'aborted') {
          if (replication != null) {
            replication.cancel();
          }
          return _this._sync(force, callback);
        }
      };
    })(this));
    return replication.once('complete', (function(_this) {
      return function(result) {
        console.log("REPLICATION COMPLETED");
        return _this.config.save({
          checkpointed: result.last_seq
        }, function(err) {
          callback(err);
          app.router.forceRefresh();
          return _this.updateIndex(function() {
            console.log('start Realtime');
            return _this.startRealtime();
          });
        });
      };
    })(this));
  };

  realtimeBackupCoef = 1;

  Replicator.prototype.startRealtime = function() {
    if (this.liveReplication) {
      return;
    }
    console.log('REALTIME START');
    this.liveReplication = this.db.replicate.from(this.config.remote, {
      batch_size: 50,
      batches_limit: 5,
      filter: this.config.makeFilterName(),
      since: this.config.get('checkpointed'),
      continuous: true
    });
    this.liveReplication.on('change', (function(_this) {
      return function(e) {
        realtimeBackupCoef = 1;
        return _this.set('inSync', true);
      };
    })(this));
    this.liveReplication.on('uptodate', (function(_this) {
      return function(e) {
        realtimeBackupCoef = 1;
        _this.set('inSync', false);
        app.router.forceRefresh();
        return console.log("UPTODATE", e);
      };
    })(this));
    this.liveReplication.once('complete', (function(_this) {
      return function(e) {
        console.log("LIVE REPLICATION CANCELLED");
        _this.set('inSync', false);
        _this.liveReplication = null;
        return _this.startRealtime();
      };
    })(this));
    return this.liveReplication.once('error', (function(_this) {
      return function(e) {
        var timeout;
        _this.liveReplication = null;
        if (realtimeBackupCoef < 6) {
          realtimeBackupCoef++;
        }
        timeout = 1000 * (1 << realtimeBackupCoef);
        console.log("REALTIME BROKE, TRY AGAIN IN " + timeout + " " + (e.toString()));
        return setTimeout(_this.startRealtime, timeout);
      };
    })(this));
  };

  return Replicator;

})(Backbone.Model);

});

require.register("replicator/replicator_backups", function(exports, require, module) {
var DeviceStatus, fs,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

DeviceStatus = require('../lib/device_status');

fs = require('./filesystem');

module.exports = {
  backup: function(callback) {
    var _ref;
    if (callback == null) {
      callback = function() {};
    }
    if (this.get('inBackup')) {
      return callback(null);
    }
    this.set('inBackup', true);
    this.set('backup_step', null);
    if ((_ref = this.liveReplication) != null) {
      _ref.cancel();
    }
    return this._backup((function(_this) {
      return function(err) {
        _this.set('backup_step', null);
        _this.set('inBackup', false);
        _this.startRealtime();
        if (err) {
          return callback(err);
        }
        return _this.config.save({
          lastBackup: new Date().toString()
        }, function(err) {
          return callback(null);
        });
      };
    })(this));
  },
  _backup: function(callback) {
    return DeviceStatus.checkReadyForSync((function(_this) {
      return function(err, ready, msg) {
        console.log("SYNC STATUS", err, ready, msg);
        if (err) {
          return callback(err);
        }
        if (!ready) {
          return callback(new Error(t(msg)));
        }
        console.log("WE ARE READY FOR SYNC");
        return _this.syncPictures(function(err) {
          if (err) {
            return callback(err);
          }
          return _this.syncContacts(function(err) {
            return callback(err);
          });
        });
      };
    })(this));
  },
  syncContacts: function(callback) {
    if (!this.config.get('syncContacts')) {
      return callback(null);
    }
    console.log("SYNC CONTACTS");
    this.set('backup_step', 'contacts_scan');
    this.set('backup_step_done', null);
    return async.parallel([
      ImagesBrowser.getContactsList, (function(_this) {
        return function(cb) {
          return _this.contactsDB.query('ContactsByLocalId', {}, cb);
        };
      })(this)
    ], (function(_this) {
      return function(err, result) {
        var dbCache, dbContacts, phoneContacts, processed, _ref;
        if (err) {
          return callback(err);
        }
        phoneContacts = result[0], (_ref = result[1], dbContacts = _ref.rows);
        console.log("BEGIN SYNC " + dbContacts.length + " " + phoneContacts.length);
        dbCache = {};
        dbContacts.forEach(function(row) {
          return dbCache[row.key] = {
            id: row.id,
            rev: row.value[1],
            version: row.value[0]
          };
        });
        processed = 0;
        _this.set('backup_step_total', phoneContacts.length);
        return async.eachSeries(phoneContacts, function(contact, cb) {
          var inDb, log;
          _this.set('backup_step_done', processed++);
          contact.localId = contact.localId.toString();
          contact.docType = 'Contact';
          inDb = dbCache[contact.localId];
          log = "CONTACT : " + contact.localId + " " + contact.localVersion;
          log += "DB " + (inDb != null ? inDb.version : void 0) + " : ";
          if (contact.localVersion === (inDb != null ? inDb.version : void 0)) {
            console.log(log + "NOTHING TO DO");
            return cb(null);
          } else if (inDb != null) {
            console.log(log + "UPDATING");
            return _this.contactsDB.put(contact, inDb.id, inDb.rev, cb);
          } else {
            console.log(log + "CREATING");
            return _this.contactsDB.post(contact, function(err, doc) {
              if (err) {
                return callback(err);
              }
              if (!doc.ok) {
                return callback(new Error('cant create'));
              }
              dbCache[contact.localId] = {
                id: doc.id,
                rev: doc.rev,
                version: contact.localVersion
              };
              return cb(null);
            });
          }
        }, function(err) {
          var ids, replication;
          if (err) {
            return callback(err);
          }
          console.log("SYNC CONTACTS phone -> pouch DONE");
          ids = _.map(dbCache, function(doc) {
            return doc.id;
          });
          _this.set('backup_step', 'contacts_sync');
          _this.set('backup_step_total', ids.length);
          replication = _this.contactsDB.replicate.to(_this.config.remote, {
            since: 0,
            doc_ids: ids
          });
          replication.on('error', callback);
          replication.on('change', function(e) {
            return _this.set('backup_step_done', e.last_seq);
          });
          return replication.on('complete', function() {
            callback(null);
            return _this.contactsDB.query('ContactsByLocalId', {}, function() {});
          });
        });
      };
    })(this));
  },
  syncPictures: function(callback) {
    if (!this.config.get('syncImages')) {
      return callback(null);
    }
    console.log("SYNC PICTURES");
    this.set('backup_step', 'pictures_scan');
    this.set('backup_step_done', null);
    return async.series([
      this.ensureDeviceFolder.bind(this), ImagesBrowser.getImagesList, (function(_this) {
        return function(cb) {
          return _this.photosDB.query('PhotosByLocalId', {}, cb);
        };
      })(this)
    ], (function(_this) {
      return function(err, results) {
        var dbImages, device, images, myDownloadFolder, toUpload, _ref;
        if (err) {
          return callback(err);
        }
        device = results[0], images = results[1], (_ref = results[2], dbImages = _ref.rows);
        console.log("SYNC IMAGES : " + images.length + " " + dbImages.length);
        dbImages = dbImages.map(function(row) {
          return row.key;
        });
        myDownloadFolder = _this.downloads.toURL().replace('file://', '');
        toUpload = [];
        return async.eachSeries(images, function(path, cb) {
          if (__indexOf.call(dbImages, path) < 0) {
            toUpload.push(path);
          }
          return setTimeout(cb, 1);
        }, function() {
          var processed;
          processed = 0;
          _this.set('backup_step', 'pictures_sync');
          _this.set('backup_step_total', toUpload.length);
          return async.eachSeries(toUpload, function(path, cb) {
            _this.set('backup_step_done', processed++);
            console.log("UPLOADING " + path);
            return _this.uploadPicture(path, device, function(err) {
              if (err) {
                console.log("ERROR " + path + " " + err);
              }
              return setTimeout(cb, 1);
            });
          }, callback);
        });
      };
    })(this));
  },
  uploadPicture: function(path, device, callback) {
    return fs.getFileFromPath(path, (function(_this) {
      return function(err, file) {
        if (err) {
          return callback(err);
        }
        return fs.contentFromFile(file, function(err, content) {
          if (err) {
            return callback(err);
          }
          return _this.createBinary(content, file.type, function(err, bin) {
            if (err) {
              return callback(err);
            }
            return _this.createFile(file, path, bin, device, function(err, res) {
              if (err) {
                return callback(err);
              }
              return _this.createPhoto(path, callback);
            });
          });
        });
      };
    })(this));
  },
  createBinary: function(blob, mime, callback) {
    return this.config.remote.post({
      docType: 'Binary'
    }, (function(_this) {
      return function(err, doc) {
        if (err) {
          return callback(err);
        }
        if (!doc.ok) {
          return callback(new Error('cant create binary'));
        }
        return _this.config.remote.putAttachment(doc.id, 'file', doc.rev, blob, mime, function(err, doc) {
          if (err) {
            return callback(err);
          }
          if (!doc.ok) {
            return callback(new Error('cant attach'));
          }
          delete _this.config.remoteHostObject.headers['Content-Type'];
          return callback(null, doc);
        });
      };
    })(this));
  },
  createFile: function(cordovaFile, localPath, binaryDoc, device, callback) {
    var dbFile;
    dbFile = {
      docType: 'File',
      localPath: localPath,
      name: cordovaFile.name,
      path: device.path + '/' + device.name,
      "class": this.fileClassFromMime(cordovaFile.type),
      lastModification: new Date(cordovaFile.lastModified).toISOString(),
      creationDate: new Date(cordovaFile.lastModified).toISOString(),
      size: cordovaFile.size,
      tags: ['uploaded-from-' + this.config.get('deviceName')],
      binary: {
        file: {
          id: binaryDoc.id,
          rev: binaryDoc.rev
        }
      }
    };
    return this.config.remote.post(dbFile, callback);
  },
  createPhoto: function(localPath, callback) {
    var dbPhoto;
    dbPhoto = {
      docType: 'Photo',
      localId: localPath
    };
    return this.photosDB.post(dbPhoto, callback);
  },
  fileClassFromMime: function(type) {
    switch (type.split('/')[0]) {
      case 'image':
        return "image";
      case 'audio':
        return "music";
      case 'video':
        return "video";
      case 'text':
      case 'application':
        return "document";
      default:
        return "file";
    }
  },
  ensureDeviceFolder: function(callback) {
    var createNew, findDevice;
    findDevice = (function(_this) {
      return function(id, callback) {
        return _this.db.get(id, function(err, res) {
          if (err == null) {
            return callback();
          } else {
            return findDevice(id, callback);
          }
        });
      };
    })(this);
    createNew = (function(_this) {
      return function() {
        var folder;
        console.log("MAKING ONE");
        folder = {
          docType: 'Folder',
          name: _this.config.get('deviceName'),
          path: '',
          lastModification: new Date().toISOString(),
          creationDate: new Date().toISOString(),
          tags: []
        };
        return _this.config.remote.post(folder, function(err, res) {
          var dbDevice;
          dbDevice = {
            docType: 'Device',
            localId: res.id
          };
          return _this.photosDB.post(dbDevice, function(err, res) {
            app.replicator.startRealtime();
            return findDevice(dbDevice.localId, function() {
              if (err) {
                return callback(err);
              }
              return callback(null, folder);
            });
          });
        });
      };
    })(this);
    return this.photosDB.query('DevicesByLocalId', {}, (function(_this) {
      return function(err, results) {
        var device;
        if (err) {
          return callback(err);
        }
        if (results.rows.length > 0) {
          device = results.rows[0];
          return _this.db.get(device.key, function(err, res) {
            if (err != null) {
              createNew();
              return this.photosDB.remove(device.value);
            } else {
              console.log("DEVICE FOLDER EXISTS");
              console.log(res);
              return callback(null, res);
            }
          });
        } else {
          return createNew();
        }
      };
    })(this));
  }
};

});

require.register("replicator/replicator_config", function(exports, require, module) {
var ReplicatorConfig, basic,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

basic = require('../lib/basic');

module.exports = ReplicatorConfig = (function(_super) {
  __extends(ReplicatorConfig, _super);

  function ReplicatorConfig(replicator) {
    this.replicator = replicator;
    ReplicatorConfig.__super__.constructor.call(this, null);
    this.remote = null;
  }

  ReplicatorConfig.prototype.defaults = function() {
    return {
      _id: 'localconfig',
      syncContacts: app.locale === 'digidisk',
      syncImages: true,
      syncOnWifi: true,
      cozyURL: '',
      deviceName: ''
    };
  };

  ReplicatorConfig.prototype.fetch = function(callback) {
    return this.replicator.db.get('localconfig', (function(_this) {
      return function(err, config) {
        if (config) {
          _this.set(config);
          _this.remote = _this.createRemotePouchInstance();
        }
        return callback(null, _this);
      };
    })(this));
  };

  ReplicatorConfig.prototype.save = function(changes, callback) {
    this.set(changes);
    return this.replicator.db.put(this.toJSON(), (function(_this) {
      return function(err, res) {
        if (err) {
          return callback(err);
        }
        if (!res.ok) {
          return callback(new Error('cant save config'));
        }
        _this.set({
          _rev: res.rev
        });
        _this.remote = _this.createRemotePouchInstance();
        return typeof callback === "function" ? callback(null, _this) : void 0;
      };
    })(this));
  };

  ReplicatorConfig.prototype.makeUrl = function(path) {
    return {
      json: true,
      auth: this.get('auth'),
      url: 'http://' + this.get('cozyURL') + '/cozy' + path
    };
  };

  ReplicatorConfig.prototype.makeFilterName = function() {
    return this.get('deviceId') + '/filter';
  };

  ReplicatorConfig.prototype.createRemotePouchInstance = function() {
    return new PouchDB({
      name: this.get('fullRemoteURL'),
      getHost: (function(_this) {
        return function() {
          return _this.remoteHostObject = {
            remote: true,
            protocol: 'http',
            host: _this.get('cozyURL'),
            port: 9104,
            path: '',
            db: 'cozy',
            headers: {
              Authorization: basic(_this.get('auth'))
            }
          };
        };
      })(this)
    });
  };

  return ReplicatorConfig;

})(Backbone.Model);

});

require.register("replicator/replicator_mapreduce", function(exports, require, module) {
var ContactsByLocalIdDesignDoc, DevicesByLocalIdDesignDoc, FilesAndFolderDesignDoc, LocalPathDesignDoc, PathToBinaryDesignDoc, PhotosByLocalIdDesignDoc, createOrUpdateDesign;

createOrUpdateDesign = function(db, design, callback) {
  return db.get(design._id, (function(_this) {
    return function(err, existing) {
      if ((existing != null ? existing.version : void 0) === design.version) {
        return callback(null);
      } else {
        console.log("REDEFINING DESIGN " + design._id + " FROM " + existing);
        if (existing) {
          design._rev = existing._rev;
        }
        return db.put(design, callback);
      }
    };
  })(this));
};

PathToBinaryDesignDoc = {
  _id: '_design/PathToBinary',
  version: 1,
  views: {
    'PathToBinary': {
      map: Object.toString.apply(function(doc) {
        var _ref, _ref1, _ref2;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file') {
          return emit(doc.path + '/' + doc.name, (_ref1 = doc.binary) != null ? (_ref2 = _ref1.file) != null ? _ref2.id : void 0 : void 0);
        }
      })
    }
  }
};

FilesAndFolderDesignDoc = {
  _id: '_design/FilesAndFolder',
  version: 1,
  views: {
    'FilesAndFolder': {
      map: Object.toString.apply(function(doc) {
        var _ref, _ref1;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file') {
          emit([doc.path, '2_' + doc.name]);
        }
        if (((_ref1 = doc.docType) != null ? _ref1.toLowerCase() : void 0) === 'folder') {
          return emit([doc.path, '1_' + doc.name]);
        }
      })
    }
  }
};

LocalPathDesignDoc = {
  _id: '_design/LocalPath',
  version: 1,
  views: {
    'LocalPath': {
      map: Object.toString.apply(function(doc) {
        if (doc.localPath) {
          return emit(doc.localPath);
        }
      })
    }
  }
};

ContactsByLocalIdDesignDoc = {
  _id: '_design/ContactsByLocalId',
  version: 1,
  views: {
    'ContactsByLocalId': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'contact' && doc.localId) {
          return emit(doc.localId, [doc.localVersion, doc._rev]);
        }
      })
    }
  }
};

PhotosByLocalIdDesignDoc = {
  _id: '_design/PhotosByLocalId',
  version: 1,
  views: {
    'PhotosByLocalId': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'photo') {
          return emit(doc.localId);
        }
      })
    }
  }
};

DevicesByLocalIdDesignDoc = {
  _id: '_design/DevicesByLocalId',
  version: 2,
  views: {
    'DevicesByLocalId': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'device') {
          return emit(doc.localId, doc);
        }
      })
    }
  }
};

module.exports = function(db, contactsDB, photosDB, callback) {
  return async.series([
    function(cb) {
      return createOrUpdateDesign(db, FilesAndFolderDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, LocalPathDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, PathToBinaryDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(contactsDB, ContactsByLocalIdDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(photosDB, PhotosByLocalIdDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(photosDB, DevicesByLocalIdDesignDoc, cb);
    }
  ], callback);
};

});

require.register("replicator/utils", function(exports, require, module) {


});

;require.register("router", function(exports, require, module) {
var ConfigView, DeviceNamePickerView, FirstSyncView, FolderCollection, FolderView, LoginView, Router, app,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

app = require('application');

FolderView = require('./views/folder');

LoginView = require('./views/login');

DeviceNamePickerView = require('./views/device_name_picker');

FirstSyncView = require('./views/first_sync');

ConfigView = require('./views/config');

FolderCollection = require('./collections/files');

module.exports = Router = (function(_super) {
  __extends(Router, _super);

  function Router() {
    return Router.__super__.constructor.apply(this, arguments);
  }

  Router.prototype.routes = {
    'folder/*path': 'folder',
    'search/*query': 'search',
    'login': 'login',
    'device-name-picker': 'deviceNamePicker',
    'first-sync': 'firstSync',
    'config': 'config'
  };

  Router.prototype.folder = function(path) {
    var backpath, collection, parts;
    $('#btn-menu, #btn-back').show();
    if (path === null) {
      app.layout.setBackButton('#folder/', 'home');
      app.layout.setTitle('Cozy');
    } else {
      parts = path.split('/');
      backpath = '#folder/' + parts.slice(0, -1).join('/');
      app.layout.setBackButton(backpath, 'ios7-arrow-back');
      app.layout.setTitle(parts[parts.length - 1]);
    }
    collection = new FolderCollection([], {
      path: path
    });
    this.display(new FolderView({
      collection: collection
    }, collection.fetch()));
    return collection.once('fullsync', (function(_this) {
      return function() {
        return _this.trigger('collectionfetched');
      };
    })(this));
  };

  Router.prototype.search = function(query) {
    var collection;
    $('#btn-menu, #btn-back').show();
    app.layout.setBackButton('#folder/', 'home');
    app.layout.setTitle(t('search') + ' "' + query + '"');
    collection = new FolderCollection([], {
      query: query
    });
    this.display(new FolderView({
      collection: collection
    }));
    return collection.search((function(_this) {
      return function(err) {
        if (err) {
          console.log(err.stack);
          return alert(err);
        }
        return $('#search-input').blur();
      };
    })(this));
  };

  Router.prototype.login = function() {
    app.layout.setTitle(t('setup 1/3'));
    $('#btn-menu, #btn-back').hide();
    return this.display(new LoginView());
  };

  Router.prototype.deviceNamePicker = function() {
    app.layout.setTitle(t('setup 2/3'));
    return this.display(new DeviceNamePickerView());
  };

  Router.prototype.firstSync = function() {
    app.layout.setTitle(t('setup end'));
    return this.display(new FirstSyncView());
  };

  Router.prototype.config = function() {
    var titleKey;
    $('#btn-back').hide();
    titleKey = app.isFirstRun ? 'setup 3/3' : 'config';
    app.layout.setTitle(t(titleKey));
    return this.display(new ConfigView());
  };

  Router.prototype.display = function(view) {
    return app.layout.transitionTo(view);
  };

  Router.prototype.forceRefresh = function() {
    var col, path, _ref;
    col = (_ref = app.layout.currentView) != null ? _ref.collection : void 0;
    if ((col != null ? col.path : void 0) === null) {
      path = '';
    } else if ((col != null ? col.path : void 0) !== void 0) {
      path = col.path;
    } else {
      return;
    }
    delete FolderCollection.cache[path];
    return col.fetch();
  };

  return Router;

})(Backbone.Router);

});

require.register("templates/config", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="list"><div class="item item-divider">');
var __val__ = t('phone2cozy title')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div>');
if ( locale == 'digidisk')
{
buf.push('<div class="item item-checkbox">');
var __val__ = t('contacts sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('contactSyncCheck'), 'type':("checkbox"), 'checked':(syncContacts) }, {"type":true,"checked":true}));
buf.push('/></label></div>');
}
buf.push('<div class="item item-checkbox">');
var __val__ = t('images sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('imageSyncCheck'), 'type':("checkbox"), 'checked':(syncImages) }, {"type":true,"checked":true}));
buf.push('/></label></div><div class="item item-checkbox">');
var __val__ = t('wifi sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('wifiSyncCheck'), 'type':("checkbox"), 'checked':(syncOnWifi) }, {"type":true,"checked":true}));
buf.push('/></label></div>');
if ( firstRun)
{
buf.push('<div class="item"><button id="configDone" class="button button-block button-balanced">');
var __val__ = t('next')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div>');
}
else
{
buf.push('<div id="doBackup" class="item item-icon-left"><i class="icon ion-clock"></i><span class="text">');
var __val__ = t('last backup')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('&nbsp;' + escape((interp = lastBackup) == null ? '' : interp) + '.</span></div><div class="item item-divider">');
var __val__ = t('about')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('synchronized with') + cozyURL
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('device name') + ' : ' + deviceName
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('app name') + ' v 0.1.0'
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item item-divider">');
var __val__ = t('reset title')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div style="padding-left: 95px; white-space: normal;" class="item item-button-left"><button id="synchrobtn" class="button button-assertive">');
var __val__ = t('retry synchro')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button>');
var __val__ = t('synchro warning')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div style="padding-left: 95px; white-space: normal;" class="item item-button-left"><button id="redbtn" class="button button-assertive">');
var __val__ = t('reset action')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button>');
var __val__ = t('reset warning')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div>');
}
buf.push('</div>');
}
return buf.join("");
};
});

require.register("templates/device_name_picker", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div id="deviceNamePicker" class="list"><div class="card"><div class="item item-text-wrap">');
var __val__ = t('device name explanation')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div></div><div class="card"><label class="item item-input item-stacked-label"><span class="input-label">');
var __val__ = t('device name')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input');
buf.push(attrs({ 'id':('input-device'), 'type':("text"), 'placeholder':("" + (t('device name placeholder')) + "") }, {"type":true,"placeholder":true}));
buf.push('/></label></div><div class="button-bar item-input"><button id="btn-back" class="button button-dark icon-left ion-chevron-left button-clear">');
var __val__ = t('back')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button><button id="btn-save" class="button button-balanced">');
var __val__ = t('next')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div></div>');
}
return buf.join("");
};
});

require.register("templates/first_sync", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="list"><div id="finishSync" class="card"><div class="progress item item-text-wrap">');
var __val__ = messageText
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div></div><div class="item-input"><button id="btn-end" class="button button-block button-balanced">');
var __val__ = buttonText
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div></div>');
}
return buf.join("");
};
});

require.register("templates/folder_line", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="item-content">');
if ( isFolder)
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
if ( isFolder)
{
buf.push('<i class="icon ion-chevron-right"></i>');
}
else if ( model.incache && model.version)
{
buf.push('<i class="cache-indicator icon ion-iphone"></i>');
}
else if ( model.incache)
{
buf.push('<i class="cache-indicator-version icon ion-iphone"></i>');
}
else
{
buf.push('<i class="cache-indicator icon ion-ios7-cloud-download-outline"></i>');
}
buf.push('</div><div class="item-options invisible">');
if ( model.incache == 'loading')
{
buf.push('<div class="button">');
var __val__ = t('loading')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div>');
}
else if ( model.incache)
{
buf.push('<div class="button uncache">');
var __val__ = t('remove local')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div>');
}
else
{
buf.push('<div class="button download">');
var __val__ = t('download')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div>');
}
buf.push('</div>');
}
return buf.join("");
};
});

require.register("templates/layout", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div id="container" class="pane"><div id="bar-header" class="bar bar-header"><a id="btn-menu" class="button button-icon"><img src="img/menu-icon-blue.png"/></a><h1 id="title" class="title">Loading</h1><a id="headerSpinner" class="button button-icon icon ion-looping"></a></div><div class="bar bar-subheader bar-calm"><h2 id="backupIndicator" class="title"></h2></div><div id="viewsPlaceholder" class="scroll-content has-header has-footer"><div class="scroll"><div class="scroll-refresher"><div class="ionic-refresher-content"><div class="icon-pulling"><i class="icon ion-arrow-down-c"></i>');
var __val__ = t('pull to sync')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="icon-refreshing"><i class="icon ion-loading-d"></i>');
var __val__ = t('syncing')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div></div></div></div></div><div class="bar bar-footer"><a id="btn-back" class="button button-icon icon ion-ios7-arrow-back"></a></div></div>');
}
return buf.join("");
};
});

require.register("templates/login", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="list"><div class="card"><label class="item item-input"><span class="input-label">');
var __val__ = t('cozy url')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input');
buf.push(attrs({ 'id':('input-url'), 'type':("url"), 'placeholder':("john.cozycloud.cc"), 'value':("" + (defaultValue.cozyURL) + "") }, {"type":true,"placeholder":true,"value":true}));
buf.push('/></label><label class="item item-input"><span class="input-label">');
var __val__ = t('cozy password')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span><input');
buf.push(attrs({ 'id':('input-pass'), 'type':("password"), 'placeholder':("" + (t('password placeholder')) + ""), 'value':("" + (defaultValue.password) + "") }, {"type":true,"placeholder":true,"value":true}));
buf.push('/></label><button id="btn-save" class="button button-block button-balanced item">');
var __val__ = t('next')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div></div>');
}
return buf.join("");
};
});

require.register("templates/menu", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<div class="bar bar-header bar-dark"><h1 class="title">Menu</h1></div><div class="content has-header"><div class="item item-input-inset"><label class="item-input-wrapper"><input');
buf.push(attrs({ 'id':('search-input'), 'type':("text"), 'placeholder':(t("search")) }, {"type":true,"placeholder":true}));
buf.push('/></label><a id="btn-search" class="button button-icon icon ion-search"></a></div><a href="#folder/" class="item item-icon-left"><i class="icon ion-home"></i>');
var __val__ = t('home')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a><a href="#config" class="item item-icon-left"><i class="icon ion-wrench"></i>');
var __val__ = t('config')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a><a id="backupButton" class="item item-icon-left"><i class="icon ion-ios7-cloud-upload-outline"></i>');
var __val__ = t('backup')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a></div>');
}
return buf.join("");
};
});

require.register("views/config", function(exports, require, module) {
var BaseView, ConfigView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = ConfigView = (function(_super) {
  __extends(ConfigView, _super);

  function ConfigView() {
    return ConfigView.__super__.constructor.apply(this, arguments);
  }

  ConfigView.prototype.template = require('../templates/config');

  ConfigView.prototype.menuEnabled = true;

  ConfigView.prototype.events = function() {
    return {
      'tap #configDone': 'configDone',
      'tap #redbtn': 'redBtn',
      'tap #synchrobtn': 'synchroBtn',
      'tap #contactSyncCheck': 'saveChanges',
      'tap #imageSyncCheck': 'saveChanges',
      'tap #wifiSyncCheck': 'saveChanges'
    };
  };

  ConfigView.prototype.getRenderData = function() {
    var config;
    config = app.replicator.config.toJSON();
    return _.extend({}, config, {
      lastSync: this.formatDate(config != null ? config.lastSync : void 0),
      lastBackup: this.formatDate(config != null ? config.lastBackup : void 0),
      firstRun: app.isFirstRun,
      locale: app.locale
    });
  };

  ConfigView.prototype.formatDate = function(date) {
    if (!date) {
      return t('never');
    } else {
      if (!(date instanceof Date)) {
        date = new Date(date);
      }
      return date.toDateString() + ' ' + date.toTimeString();
    }
  };

  ConfigView.prototype.configDone = function() {
    return app.router.navigate('first-sync', {
      trigger: true
    });
  };

  ConfigView.prototype.redBtn = function() {
    if (confirm(t('confirm message'))) {
      return app.replicator.destroyDB((function(_this) {
        return function(err) {
          if (err) {
            return alert(err.message);
          }
          $('#redbtn').text(t('done'));
          return window.location.reload(true);
        };
      })(this));
    }
  };

  ConfigView.prototype.synchroBtn = function() {
    if (confirm(t('confirm message'))) {
      return app.replicator.resetSynchro((function(_this) {
        return function(err) {
          if (err) {
            return alert(err.message);
          }
          return app.router.navigate('first-sync', {
            trigger: true
          });
        };
      })(this));
    }
  };

  ConfigView.prototype.saveChanges = function() {
    this.$('#contactSyncCheck, #imageSyncCheck, #wifiSyncCheck').prop('disabled', true);
    return app.replicator.config.save({
      syncContacts: this.$('#contactSyncCheck').is(':checked'),
      syncImages: this.$('#imageSyncCheck').is(':checked'),
      syncOnWifi: this.$('#wifiSyncCheck').is(':checked')
    }, (function(_this) {
      return function() {
        return _this.$('#contactSyncCheck, #imageSyncCheck, #wifiSyncCheck').prop('disabled', false);
      };
    })(this));
  };

  return ConfigView;

})(BaseView);

});

require.register("views/device_name_picker", function(exports, require, module) {
var BaseView, DeviceNamePickerView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = DeviceNamePickerView = (function(_super) {
  __extends(DeviceNamePickerView, _super);

  function DeviceNamePickerView() {
    return DeviceNamePickerView.__super__.constructor.apply(this, arguments);
  }

  DeviceNamePickerView.prototype.className = 'list';

  DeviceNamePickerView.prototype.template = require('../templates/device_name_picker');

  DeviceNamePickerView.prototype.events = function() {
    return {
      'click #btn-save': 'doSave',
      'click #btn-back': 'doBack',
      'keypress #input-device': 'blurIfEnter'
    };
  };

  DeviceNamePickerView.prototype.doBack = function() {
    return app.router.navigate('login', {
      trigger: true
    });
  };

  DeviceNamePickerView.prototype.blurIfEnter = function(e) {
    if (e.keyCode === 13) {
      return this.$('#input-device').blur();
    }
  };

  DeviceNamePickerView.prototype.doSave = function() {
    var config, device;
    if (this.saving) {
      return null;
    }
    this.saving = $('#btn-save').text();
    if (this.error) {
      this.error.remove();
    }
    device = this.$('#input-device').val();
    if (!device) {
      return this.displayError('all fields are required');
    }
    config = app.loginConfig;
    config.deviceName = device;
    $('#btn-save').text(t('registering...'));
    return app.replicator.registerRemote(config, (function(_this) {
      return function(err) {
        var noop;
        if (err != null) {
          return _this.displayError(err.message);
        } else {
          delete app.loginConfig;
          app.isFirstRun = true;
          console.log('starting first replication');
          noop = function() {};
          app.replicator.initialReplication(noop);
          return app.router.navigate('config', {
            trigger: true
          });
        }
      };
    })(this));
  };

  DeviceNamePickerView.prototype.displayError = function(text, field) {
    $('#btn-save').text(this.saving);
    this.saving = false;
    if (this.error) {
      this.error.remove();
    }
    if (~text.indexOf('CORS request rejected')) {
      text = t('connection failure');
    }
    this.error = $('<div>').addClass('button button-full button-energized');
    this.error.text(text);
    return this.$(field || 'label').after(this.error);
  };

  return DeviceNamePickerView;

})(BaseView);

});

require.register("views/first_sync", function(exports, require, module) {
var BaseView, FirstSyncView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = FirstSyncView = (function(_super) {
  __extends(FirstSyncView, _super);

  function FirstSyncView() {
    return FirstSyncView.__super__.constructor.apply(this, arguments);
  }

  FirstSyncView.prototype.className = 'list';

  FirstSyncView.prototype.template = require('../templates/first_sync');

  FirstSyncView.prototype.events = function() {
    return {
      'tap #btn-end': 'end'
    };
  };

  FirstSyncView.prototype.getRenderData = function() {
    var buttonText, messageText, percent;
    percent = app.replicator.get('initialReplicationRunning') || 0;
    if (percent && percent === 1) {
      messageText = t('ready message');
      buttonText = t('end');
    } else if (percent < -1) {
      messageText = t('wait message device');
      buttonText = t('waiting...');
    } else if (percent < 0) {
      messageText = t('wait message cozy');
      buttonText = t('waiting...');
    } else if (percent === 0.90) {
      messageText = t('wait message display');
      buttonText = t('waiting...');
    } else {
      messageText = t('wait message', {
        progress: 5 + parseInt(percent * 100)
      });
      buttonText = t('waiting...');
    }
    return {
      messageText: messageText,
      buttonText: buttonText
    };
  };

  FirstSyncView.prototype.initialize = function() {
    return this.listenTo(app.replicator, 'change:initialReplicationRunning', this.onChange);
  };

  FirstSyncView.prototype.onChange = function(replicator) {
    var percent;
    percent = replicator.get('initialReplicationRunning');
    if (percent === 0.90) {
      this.$('#finishSync .progress').text(t('wait message display'));
    } else {
      this.$('#finishSync .progress').text(t('wait message', {
        progress: 5 + parseInt(percent * 100)
      }));
    }
    if (percent >= 1) {
      return this.render();
    }
  };

  FirstSyncView.prototype.end = function() {
    var percent;
    percent = parseInt(app.replicator.get('initialReplicationRunning'));
    console.log("end " + percent);
    if (percent !== 1) {
      return;
    }
    app.replicator.backup(function(err) {
      if (err) {
        alert(err);
      }
      return console.log("pics & contacts synced");
    });
    app.isFirstRun = false;
    return app.router.navigate('folder/', {
      trigger: true
    });
  };

  return FirstSyncView;

})(BaseView);

});

require.register("views/folder", function(exports, require, module) {
var CollectionView, FolderView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

CollectionView = require('../lib/view_collection');

module.exports = FolderView = (function(_super) {
  __extends(FolderView, _super);

  function FolderView() {
    this.displaySlider = __bind(this.displaySlider, this);
    this.remove = __bind(this.remove, this);
    this.appendView = __bind(this.appendView, this);
    this.onChange = __bind(this.onChange, this);
    return FolderView.__super__.constructor.apply(this, arguments);
  }

  FolderView.prototype.className = 'list';

  FolderView.prototype.itemview = require('./folder_line');

  FolderView.prototype.pullToRefreshEnabled = true;

  FolderView.prototype.menuEnabled = true;

  FolderView.prototype.events = function() {
    return {
      'tap .cache-indicator': 'displaySlider',
      'hold .item': 'displaySlider'
    };
  };

  FolderView.prototype.isParentOf = function(otherFolderView) {
    if (this.collection.path === null) {
      return true;
    }
    if (this.collection.isSearch()) {
      return false;
    }
    if (!otherFolderView.collection.path) {
      return false;
    }
    return -1 !== otherFolderView.collection.path.indexOf(this.collection.path);
  };

  FolderView.prototype.initialize = function() {
    FolderView.__super__.initialize.apply(this, arguments);
    return this.listenTo(this.collection, 'sync', this.onChange);
  };

  FolderView.prototype.afterRender = function() {
    var _ref;
    if ((_ref = this.ionicView) != null) {
      _ref.destroy();
    }
    FolderView.__super__.afterRender.apply(this, arguments);
    return this.ionicView = new ionic.views.ListView({
      el: this.$el[0],
      _handleDrag: function(e) {
        ionic.views.ListView.prototype._handleDrag.apply(this, arguments);
        e.preventDefault();
        return e.stopPropagation();
      }
    });
  };

  FolderView.prototype.onChange = function() {
    var message;
    this.$('#empty-message').remove();
    if (_.size(this.views) === 0) {
      message = this.collection.notloaded ? 'loading' : this.collection.isSearch() ? 'no results' : 'this folder is empty';
      return $('<li class="item" id="empty-message">').text(t(message)).appendTo(this.$el);
    }
  };

  FolderView.prototype.appendView = function(view) {
    FolderView.__super__.appendView.apply(this, arguments);
    return view.parent = this;
  };

  FolderView.prototype.remove = function() {
    FolderView.__super__.remove.apply(this, arguments);
    return this.collection.cancelFetchAdditional();
  };

  FolderView.prototype.displaySlider = function(event) {
    var dX, op;
    console.log("DISPLAY SLIDER");
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
    ionic.requestAnimationFrame((function(_this) {
      return function() {
        return _this.ionicView._lastDragOp = op;
      };
    })(this));
    event.preventDefault();
    return event.stopPropagation();
  };

  return FolderView;

})(CollectionView);

});

require.register("views/folder_line", function(exports, require, module) {
var BaseView, FolderLineView,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = FolderLineView = (function(_super) {
  __extends(FolderLineView, _super);

  function FolderLineView() {
    this.removeFromCache = __bind(this.removeFromCache, this);
    this.addToCache = __bind(this.addToCache, this);
    this.onClick = __bind(this.onClick, this);
    this.updateProgress = __bind(this.updateProgress, this);
    this.hideProgress = __bind(this.hideProgress, this);
    this.displayProgress = __bind(this.displayProgress, this);
    this.setCacheIcon = __bind(this.setCacheIcon, this);
    this.afterRender = __bind(this.afterRender, this);
    this.initialize = __bind(this.initialize, this);
    return FolderLineView.__super__.constructor.apply(this, arguments);
  }

  FolderLineView.prototype.tagName = 'a';

  FolderLineView.prototype.template = require('../templates/folder_line');

  FolderLineView.prototype.events = {
    'tap .item-content': 'onClick',
    'tap .item-options .download': 'addToCache',
    'tap .item-options .uncache': 'removeFromCache'
  };

  FolderLineView.prototype.className = 'item item-icon-left item-icon-right item-complex';

  FolderLineView.prototype.initialize = function() {
    return this.listenTo(this.model, 'change', this.render);
  };

  FolderLineView.prototype.getRenderData = function() {
    return _.extend(FolderLineView.__super__.getRenderData.apply(this, arguments), {
      isFolder: this.model.isFolder()
    });
  };

  FolderLineView.prototype.afterRender = function() {
    this.$el[0].dataset.folderid = this.model.get('_id');
    if (this.model.isDeviceFolder) {
      return this.$('.ion-folder').css({
        color: '#34a6ff'
      });
    }
  };

  FolderLineView.prototype.setCacheIcon = function(klass) {
    var icon, _ref, _ref1;
    icon = this.$('.cache-indicator');
    icon.removeClass('ion-warning ion-looping ion-ios7-cloud-download-outline');
    icon.removeClass('ion-ios7-download-outline').addClass(klass);
    return (_ref = this.parent) != null ? (_ref1 = _ref.ionicView) != null ? _ref1.clearDragEffects() : void 0 : void 0;
  };

  FolderLineView.prototype.displayProgress = function() {
    this.downloading = true;
    this.hideProgress();
    this.setCacheIcon('ion-looping');
    this.progresscontainer = $('<div class="item-progress"></div>').append(this.progressbar = $('<div class="item-progress-bar"></div>'));
    return this.progresscontainer.appendTo(this.$el);
  };

  FolderLineView.prototype.hideProgress = function(err, incache) {
    var version, _ref;
    this.downloading = false;
    if (err) {
      alert(err);
    }
    incache = app.replicator.fileInFileSystem;
    version = app.replicator.fileVersion;
    if ((incache != null) && incache !== this.model.get('incache')) {
      this.model.set({
        incache: incache
      });
    }
    if ((version != null) && version !== this.model.get('version')) {
      this.model.set({
        version: version
      });
    }
    return (_ref = this.progresscontainer) != null ? _ref.remove() : void 0;
  };

  FolderLineView.prototype.updateProgress = function(done, total) {
    var _ref;
    return (_ref = this.progressbar) != null ? _ref.css('width', (100 * done / total) + '%') : void 0;
  };

  FolderLineView.prototype.onClick = function(event) {
    var path;
    if ($(event.target).closest('.cache-indicator').length) {
      return true;
    }
    if (this.downloading) {
      return true;
    }
    if (this.model.isFolder()) {
      path = this.model.get('path') + '/' + this.model.get('name');
      app.router.navigate("#folder" + path, {
        trigger: true
      });
      return true;
    }
    this.displayProgress();
    return app.replicator.getBinary(this.model.attributes, this.updateProgress, (function(_this) {
      return function(err, url) {
        _this.hideProgress();
        if (err) {
          return alert(err);
        }
        _this.model.set({
          incache: true
        });
        _this.model.set({
          version: app.replicator.fileVersion(_this.model.attributes)
        });
        app.backFromOpen = true;
        return ExternalFileUtil.openWith(url, '', void 0, function(success) {}, function(err) {
          if (0 === (err != null ? err.indexOf('No Activity found') : void 0)) {
            err = t('no activity found');
          }
          alert(err);
          return console.log(err);
        });
      };
    })(this));
  };

  FolderLineView.prototype.addToCache = function() {
    var onadded;
    if (this.downloading) {
      return true;
    }
    this.displayProgress();
    onadded = (function(_this) {
      return function(err) {
        _this.hideProgress();
        if (err) {
          return alert(err);
        }
        _this.model.set({
          incache: true
        });
        return _this.model.set({
          version: app.replicator.fileVersion(_this.model.attributes)
        });
      };
    })(this);
    if (this.model.isFolder()) {
      return app.replicator.getBinaryFolder(this.model.attributes, this.updateProgress, onadded);
    } else {
      return app.replicator.getBinary(this.model.attributes, this.updateProgress, onadded);
    }
  };

  FolderLineView.prototype.removeFromCache = function() {
    var onremoved;
    if (this.downloading) {
      return true;
    }
    this.displayProgress();
    onremoved = (function(_this) {
      return function(err) {
        _this.hideProgress();
        if (err) {
          return alert(err);
        }
        return _this.model.set({
          incache: false
        });
      };
    })(this);
    if (this.model.isFolder()) {
      return app.replicator.removeLocalFolder(this.model.attributes, onremoved);
    } else {
      return app.replicator.removeLocal(this.model.attributes, onremoved);
    }
  };

  return FolderLineView;

})(BaseView);

});

require.register("views/layout", function(exports, require, module) {
var BaseView, FolderView, Layout, Menu,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

FolderView = require('./folder');

Menu = require('./menu');

module.exports = Layout = (function(_super) {
  __extends(Layout, _super);

  function Layout() {
    this.onBackButtonClicked = __bind(this.onBackButtonClicked, this);
    this.onSearchButtonClicked = __bind(this.onSearchButtonClicked, this);
    this.onMenuButtonClicked = __bind(this.onMenuButtonClicked, this);
    this.setTitle = __bind(this.setTitle, this);
    this.setBackButton = __bind(this.setBackButton, this);
    this.closeMenu = __bind(this.closeMenu, this);
    this.togglePullToRefresh = __bind(this.togglePullToRefresh, this);
    return Layout.__super__.constructor.apply(this, arguments);
  }

  Layout.prototype.template = require('../templates/layout');

  Layout.prototype.events = function() {
    return {
      'tap #btn-back': 'onBackButtonClicked',
      'tap #btn-menu': 'onMenuButtonClicked'
    };
  };

  Layout.prototype.initialize = function() {
    var OpEvents;
    document.addEventListener("menubutton", this.onMenuButtonClicked, false);
    document.addEventListener("searchbutton", this.onSearchButtonClicked, false);
    document.addEventListener("backbutton", this.onBackButtonClicked, false);
    this.listenTo(app.replicator, 'change:inSync change:inBackup', (function(_this) {
      return function() {
        var inBackup, inSync;
        inSync = app.replicator.get('inSync');
        inBackup = app.replicator.get('inBackup');
        _this.spinner.toggle(inSync || inBackup);
        return _this.refresher.toggleClass('refreshing', inSync);
      };
    })(this));
    OpEvents = 'change:inBackup change:backup_step change:backup_step_done';
    return this.listenTo(app.replicator, OpEvents, _.debounce((function(_this) {
      return function() {
        var step, text;
        step = app.replicator.get('backup_step');
        if (step && (step !== 'pictures_scan' && step !== 'contacts_scan')) {
          text = t(step);
          if (app.replicator.get('backup_step_done')) {
            text += ": " + (app.replicator.get('backup_step_done'));
            text += "/" + (app.replicator.get('backup_step_total'));
          }
          _this.backupIndicator.text(text).parent().slideDown();
          return _this.viewsPlaceholder.addClass('has-subheader');
        } else {
          _this.backupIndicator.parent().slideUp();
          return _this.viewsPlaceholder.removeClass('has-subheader');
        }
      };
    })(this), 100));
  };

  Layout.prototype.afterRender = function() {
    var onActive, onClose, onStart;
    this.menu = new Menu();
    this.menu.render();
    this.$el.append(this.menu.$el);
    this.container = this.$('#container');
    this.viewsPlaceholder = this.$('#viewsPlaceholder');
    this.viewsBlock = this.viewsPlaceholder.find('.scroll');
    this.refresher = this.viewsBlock.find('.scroll-refresher');
    this.backButton = this.container.find('#btn-back');
    this.menuButton = this.container.find('#btn-menu');
    this.spinner = this.container.find('#headerSpinner');
    this.spinner.hide();
    this.title = this.container.find('#title');
    this.backupIndicator = this.container.find('#backupIndicator');
    this.backupIndicator.parent().hide();
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
    this.ionicScroll = new ionic.views.Scroll({
      el: this.viewsPlaceholder[0]
    });
    this.ionicScroll.scrollTo(1, 0, true, null);
    this.ionicScroll.scrollTo(0, 0, true, null);
    return this.ionicScroll.activatePullToRefresh(50, onActive = (function(_this) {
      return function() {
        _this.refresher.addClass('active');
        return console.log("ON ACTIVE");
      };
    })(this), onClose = (function(_this) {
      return function() {
        console.log("ON CLOSE");
        return _this.refresher.removeClass('active');
      };
    })(this), onStart = (function(_this) {
      return function() {
        _this.ionicScroll.finishPullToRefresh();
        return app.replicator.sync(function(err) {
          if (err) {
            return console.log(err);
          }
        });
      };
    })(this));
  };

  Layout.prototype.togglePullToRefresh = function(activated) {
    this.refresher.toggle(activated);
    this.ionicScroll.options.bouncing = activated;
    return this.ionicScroll.__refreshHeight = activated ? 50 : null;
  };

  Layout.prototype.closeMenu = function() {
    return this.controller.toggleLeft(false);
  };

  Layout.prototype.setBackButton = function(href, icon) {
    this.backButton.attr('href', href);
    this.backButton.removeClass('ion-home ion-ios7-arrow-back');
    return this.backButton.addClass('ion-' + icon);
  };

  Layout.prototype.setTitle = function(text) {
    return this.title.text(text);
  };

  Layout.prototype.transitionTo = function(view) {
    var $next, currClass, menuEnabled, nextClass, ptrEnabled, transitionend, type, _ref;
    this.closeMenu();
    $next = view.render().$el;
    ptrEnabled = (view.pullToRefreshEnabled != null) && view.pullToRefreshEnabled;
    this.togglePullToRefresh(ptrEnabled);
    menuEnabled = (view.menuEnabled != null) && view.menuEnabled;
    this.ionicMenu.setIsEnabled(menuEnabled);
    if (this.currentView instanceof FolderView && view instanceof FolderView) {
      type = this.currentView.isParentOf(view) ? 'left' : 'right';
    } else {
      type = 'none';
    }
    if (type === 'none') {
      if ((_ref = this.currentView) != null) {
        _ref.remove();
      }
      this.viewsBlock.append($next);
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
      return $next.one(transitionend, _.once((function(_this) {
        return function() {
          _this.currentView.remove();
          _this.currentView = view;
          return _this.ionicScroll.scrollTo(0, 0, true, null);
        };
      })(this)));
    }
  };

  Layout.prototype.onMenuButtonClicked = function() {
    this.menu.reset();
    return this.controller.toggleLeft();
  };

  Layout.prototype.onSearchButtonClicked = function() {
    this.onMenuButtonClicked();
    return this.$('#search-input').focus();
  };

  Layout.prototype.onBackButtonClicked = function(event) {
    app.router.navigate(this.backButton.attr('href'), {
      trigger: true
    });
    event.preventDefault();
    return event.stopPropagation();
  };

  return Layout;

})(BaseView);

});

require.register("views/login", function(exports, require, module) {
var BaseView, LoginView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = LoginView = (function(_super) {
  __extends(LoginView, _super);

  function LoginView() {
    return LoginView.__super__.constructor.apply(this, arguments);
  }

  LoginView.prototype.className = 'list';

  LoginView.prototype.template = require('../templates/login');

  LoginView.prototype.events = function() {
    return {
      'click #btn-save': 'doSave',
      'click #input-pass': 'doComplete'
    };
  };

  LoginView.prototype.getRenderData = function() {
    var defaultValue;
    defaultValue = app.loginConfig || {
      cozyURL: '',
      password: ''
    };
    return {
      defaultValue: defaultValue
    };
  };

  LoginView.prototype.doComplete = function() {
    var url;
    console.log("doComplete");
    url = this.$('#input-url').val();
    console.log(url.indexOf('.'));
    if (url.indexOf('.') === -1) {
      console.log(url + ".cozycloud.cc");
      return this.$('#input-url').val(url + ".cozycloud.cc");
    }
  };

  LoginView.prototype.doSave = function() {
    var config, pass, url;
    if (this.saving) {
      return null;
    }
    this.saving = $('#btn-save').text();
    if (this.error) {
      this.error.remove();
    }
    url = this.$('#input-url').val();
    pass = this.$('#input-pass').val();
    if (!(url && pass)) {
      return this.displayError('all fields are required');
    }
    if (url.slice(0, 4) === 'http') {
      url = url.replace('https://', '').replace('http://', '');
      this.$('#input-url').val(url);
    }
    if (url[url.length - 1] === '/') {
      this.$('#input-url').val(url = url.slice(0, -1));
    }
    config = {
      cozyURL: url,
      password: pass
    };
    $('#btn-save').text(t('authenticating...'));
    return app.replicator.checkCredentials(config, (function(_this) {
      return function(error) {
        if (error != null) {
          return _this.displayError(error);
        } else {
          app.loginConfig = config;
          console.log('check credentials done');
          return app.router.navigate('device-name-picker', {
            trigger: true
          });
        }
      };
    })(this));
  };

  LoginView.prototype.displayError = function(text, field) {
    $('#btn-save').text(this.saving);
    this.saving = false;
    if (this.error) {
      this.error.remove();
    }
    if (~text.indexOf('CORS request rejected')) {
      text = t('connection failure');
    }
    this.error = $('<div>').addClass('button button-full button-energized');
    this.error.text(text);
    return this.$(field || '#btn-save').before(this.error);
  };

  return LoginView;

})(BaseView);

});

require.register("views/menu", function(exports, require, module) {
var BaseView, Menu,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = Menu = (function(_super) {
  var setLooping;

  __extends(Menu, _super);

  function Menu() {
    this.doSearchIfEnter = __bind(this.doSearchIfEnter, this);
    return Menu.__super__.constructor.apply(this, arguments);
  }

  Menu.prototype.id = 'menu';

  Menu.prototype.className = 'menu menu-left';

  Menu.prototype.template = require('../templates/menu');

  Menu.prototype.events = {
    'click #syncButton': 'sync',
    'click #backupButton': 'backup',
    'click #btn-search': 'doSearch',
    'click a.item': 'closeMenu',
    'keydown #search-input': 'doSearchIfEnter'
  };

  setLooping = function(btn, looping) {
    var newIcon, oldIcon;
    oldIcon = looping ? 'ion-ios7-cloud-upload-outline' : 'ion-looping';
    newIcon = looping ? 'ion-looping' : 'ion-ios7-cloud-upload-outline';
    return btn.find('i').removeClass(oldIcon).addClass(newIcon);
  };

  Menu.prototype.afterRender = function() {
    this.syncButton = this.$('#syncButton');
    this.backupButton = this.$('#backupButton');
    this.listenTo(app.replicator, 'change:inSync', (function(_this) {
      return function() {
        return setLooping(_this.syncButton, app.replicator.get('inSync'));
      };
    })(this));
    this.listenTo(app.replicator, 'change:inBackup', (function(_this) {
      return function() {
        return setLooping(_this.backupButton, app.replicator.get('inBackup'));
      };
    })(this));
    setLooping(this.syncButton, app.replicator.get('inSync'));
    return setLooping(this.backupButton, app.replicator.get('inBackup'));
  };

  Menu.prototype.closeMenu = function() {
    return app.layout.closeMenu();
  };

  Menu.prototype.sync = function() {
    if (app.replicator.get('inSync')) {
      return;
    }
    app.layout.closeMenu();
    return app.replicator.sync(function(err) {
      var _ref, _ref1;
      if (err) {
        console.log(err, err.stack);
      }
      if (err) {
        alert(err);
      }
      return (_ref = app.layout.currentView) != null ? (_ref1 = _ref.collection) != null ? _ref1.fetch() : void 0 : void 0;
    });
  };

  Menu.prototype.backup = function() {
    if (app.replicator.get('inBackup')) {
      return;
    }
    app.layout.closeMenu();
    return app.replicator.backup(function(err) {
      var _ref, _ref1;
      if (err) {
        console.log(err, err.stack);
      }
      if (err) {
        alert(err);
      }
      return (_ref = app.layout.currentView) != null ? (_ref1 = _ref.collection) != null ? _ref1.fetch() : void 0 : void 0;
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
    return this.$('#search-input').blur().val('');
  };

  return Menu;

})(BaseView);

});


//# sourceMappingURL=app.js.map