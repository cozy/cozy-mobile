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

Replicator = require('./lib/couchbase');

module.exports = {
  initialize: function() {
    var Router, e, locales, _ref,
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
    if ((_ref = window.cblite) == null) {
      window.cblite = {
        getURL: function(cb) {
          return cb(null, 'http://localhost:5984/');
        }
      };
    }
    this.replicator = new Replicator();
    $('#header').on('click', function() {
      return _this.replicator.destroyDB(function(err) {
        return $('#header').text(err != null ? err.message : void 0);
      });
    });
    return this.replicator.init(function(err, config) {
      if (err) {
        return alert(err.message);
      }
      Backbone.history.start();
      if (config) {
        _this.replicator.sync(function(err) {
          return console.log("SYNC OVER", err);
        });
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

  FileAndFolderCollection.prototype.parse = function(couchdb_result) {
    return couchdb_result.rows.map(function(row) {
      return row.value;
    });
  };

  return FileAndFolderCollection;

})(Backbone.Collection);

FileAndFolderCollection.getAtPath = function(path) {
  var col;

  if (!path) {
    path = '';
  } else {
    path = '/' + path;
  }
  col = new FileAndFolderCollection();
  col.url = app.replicator.db + '/_design/folder/_view/byFolder?key=%22' + path + '%22';
  col.fetch({
    remove: false
  });
  col.url = app.replicator.db + '/_design/file/_view/byFolder?key=%22' + path + '%22';
  col.fetch({
    remove: false
  });
  console.log("col was fetched", col.url);
  return col;
};

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

;require.register("lib/couchbase", function(exports, require, module) {
var DBNAME, Replicator, createView, makeFilter, makeView, request, urlparse,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

request = require('./request');

urlparse = require('./url');

DBNAME = "cozy-files";

module.exports = Replicator = (function() {
  function Replicator() {
    this.status_replication = __bind(this.status_replication, this);
  }

  Replicator.prototype.server = null;

  Replicator.prototype.db = null;

  Replicator.prototype.config = null;

  Replicator.prototype.destroyDB = function(callback) {
    return request.couch({
      url: this.db,
      method: 'DELETE'
    }, callback);
  };

  Replicator.prototype.init = function(callback) {
    var _this = this;

    return window.cblite.getURL(function(err, server) {
      if (err) {
        return callback(err);
      }
      _this.server = server;
      _this.db = server + DBNAME;
      return request.get(_this.db, function(err, response, body) {
        if (response.statusCode === 404) {
          return _this.prepareDatabase(callback);
        } else if (response.statusCode === 200) {
          return _this.loadConfig(callback);
        } else {
          if (err == null) {
            err = new Error('unexpected db state');
          }
          return callback(err);
        }
      });
    });
  };

  Replicator.prototype.loadConfig = function(callback) {
    var _this = this;

    return request.couch("" + this.db + "/config", function(err, res, config) {
      if (res.statusCode === 404) {
        return callback(null, null);
      } else if (res.statusCode === 200) {
        return callback(null, _this.config = config);
      } else {
        if (err == null) {
          err = new Error('unexpected config state');
        }
        return callback(err);
      }
    });
  };

  Replicator.prototype.prepareDatabase = function(callback) {
    var _this = this;

    return request.put(this.db, function(err) {
      var fullPath, ops;

      if (err) {
        return cb(err);
      }
      fullPath = "path.toLowerCase() + '/' + doc.name.toLowerCase()";
      ops = [];
      ops.push(createView(_this.db, 'Device', {
        all: makeView('Device', '_id'),
        byUrl: makeView('Device', 'url')
      }));
      ops.push(createView(_this.db, 'File', {
        all: makeView('File', '_id'),
        byFolder: makeView('File', 'path.toLowerCase()'),
        byFullPath: makeView('File', fullPath)
      }));
      ops.push(createView(_this.db, 'Folder', {
        all: makeView('Folder', '_id'),
        byFolder: makeView('Folder', 'path.toLowerCase()'),
        byFullPath: makeView('Folder', fullPath)
      }));
      ops.push(createView(_this.db, 'Binary', {
        all: makeView('Device', '_id')
      }));
      return async.series(ops, function(err) {
        return callback(err);
      });
    });
  };

  Replicator.prototype.prepareDevice = function(callback) {
    var config, ops,
      _this = this;

    config = this.config;
    ops = [];
    ops.push(function(cb) {
      return request.couch({
        url: "" + _this.db + "/config",
        method: 'PUT',
        body: config
      }, cb);
    });
    ops.push(function(cb) {
      return request.couch({
        uri: "" + _this.db + "/_design/" + config.deviceId,
        method: 'PUT',
        body: {
          views: {},
          filters: {
            filter: makeFilter(['Folder', 'File']),
            filterDocType: makeFilter(['Folder', 'File'], true)
          }
        }
      }, cb);
    });
    return async.series(ops, callback);
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
        return callback(new Error('ds need patch'));
      } else if (response.statusCode === 401) {
        return callback(new Error('wrong password'));
      } else if (response.statusCode === 400) {
        return callback(new Error('device name already exist'));
      } else {
        config.password = body.password;
        config.deviceId = body.id;
        config.fullRemoteURL = ("https://" + config.deviceName + ":" + config.password) + ("@" + config.cozyURL + "/cozy");
        _this.config = config;
        return _this.prepareDevice(callback);
      }
    });
  };

  Replicator.prototype.replicateToLocalOneShotNoDeleted = function(callback) {
    return this.start_replication({
      source: this.config.fullRemoteURL,
      target: DBNAME,
      filter: "" + this.config.deviceId + "/filter"
    }, callback);
  };

  Replicator.prototype.sync = function(callback) {
    var _this = this;

    return this.start_replication({
      source: this.config.fullRemoteURL,
      target: DBNAME,
      continuous: true,
      filter: "" + this.config.deviceId + "/filterDocType"
    }, function(err) {
      if (err) {
        return callback(err);
      }
      return _this.start_replication({
        source: DBNAME,
        target: _this.config.fullRemoteURL,
        continuous: true,
        filter: "" + _this.config.deviceId + "/filterDocType"
      }, callback);
    });
  };

  Replicator.prototype.start_replication = function(options, callback) {
    var _this = this;

    return request.couch({
      url: "" + this.server + "_replicate",
      method: "POST",
      body: options
    }, function(err, response, replication) {
      if (err) {
        return callback(err);
      }
      if (!options.continuous) {
        return callback(null, replication);
      }
      return _this.status_replication(replication._local_id, callback);
    });
  };

  Replicator.prototype.cancel_replication = function(options, callback) {
    options.cancel = true;
    return request.couch({
      url: "" + this.server + "_replicate",
      method: "POST",
      body: options
    }, callback);
  };

  Replicator.prototype.status_replication = function(id, callback) {
    var _this = this;

    return request.couch({
      url: "" + this.server + "_active_tasks",
      method: "GET"
    }, function(err, response, tasks) {
      var next, task, _ref;

      if (err) {
        return callback(err);
      }
      task = _.findWhere(tasks, {
        replication_id: id
      });
      if (!task) {
        return callback(new Error('lost replication'));
      }
      if (task.error) {
        return callback(task.error[1]);
      }
      if ((_ref = task.status) === 'Idle' || _ref === 'Stopped') {
        return callback(null);
      }
      if (/Processed/.test(task.status) && !/Processed 0/.test(task.status)) {
        return callback(null);
      }
      if (/Processed 0 \/ 0 changes/.test(task.status)) {
        return callback(null);
      }
      next = _this.status_replication.bind(_this, id, callback);
      return setTimeout(next, 1000);
    });
  };

  return Replicator;

})();

createView = function(db, docType, views) {
  return function(callback) {
    return request.couch({
      uri: "" + db + "/_design/" + (docType.toLowerCase()),
      method: 'PUT',
      body: {
        views: views
      }
    }, callback);
  };
};

makeView = function(docType, field) {
  var fn;

  fn = function(doc) {
    if (doc.docType === '[DOCTYPE]') {
      return emit(doc.__field__, doc);
    }
  };
  fn = fn.toString().replace('[DOCTYPE]', docType);
  fn = fn.replace('__field__', field);
  return {
    map: fn
  };
};

makeFilter = function(docTypes, allowDeleted) {
  var fn;

  fn = allowDeleted ? function(doc) {
    var _ref;

    return (_ref = doc.docType, __indexOf.call(docTypes, _ref) >= 0);
  } : function(doc) {
    var _ref;

    return !doc._deleted && (_ref = doc.docType, __indexOf.call(docTypes, _ref) >= 0);
  };
  return fn = fn.toString().replace('docTypes', JSON.stringify(docTypes));
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
      er = new Error('CouchDB error: ' + (body.error.reason || body.error.error))
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
var ConfigView, FolderCollection, FolderView, Router, app, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

app = require('application');

FolderView = require('./views/folder');

ConfigView = require('./views/config');

FolderCollection = require('./collections/files');

module.exports = Router = (function(_super) {
  __extends(Router, _super);

  function Router() {
    _ref = Router.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Router.prototype.routes = {
    'folder/*path': 'folder',
    'config': 'config'
  };

  Router.prototype.folder = function(path) {
    if (path === null) {
      app.backButton.attr('href', '#folder/').removeClass('ion-ios7-arrow-back').addClass('ion-home');
    } else {
      app.backButton.attr('href', '#folder/' + path.split('/').slice(0, -1)).removeClass('ion-home').addClass('ion-ios7-arrow-back');
    }
    return this.display(new FolderView({
      collection: FolderCollection.getAtPath(path)
    }));
  };

  Router.prototype.config = function() {
    return this.display(new ConfigView());
  };

  Router.prototype.display = function(view) {
    if (this.mainView) {
      this.mainView.remove();
    }
    this.mainView = view.render();
    return $('#mainContent').append(this.mainView.$el);
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
}
return buf.join("");
};
});

;require.register("views/config", function(exports, require, module) {
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
    config = {
      cozyURL: url,
      password: pass,
      deviceName: device
    };
    return app.replicator.registerRemote(config, function(err) {
      if (err) {
        return _this.displayError(err.message);
      }
      $('#footer').text('begin replication');
      return app.replicator.replicateToLocalOneShotNoDeleted(function(err) {
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

  FolderView.prototype.className = 'list';

  FolderView.prototype.itemview = require('./folder_line');

  return FolderView;

})(CollectionView);

});

;require.register("views/folder_line", function(exports, require, module) {
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

  ConfigView.prototype.tagName = 'a';

  ConfigView.prototype.className = 'item item-icon-left';

  ConfigView.prototype.attributes = function() {
    var path;

    path = this.model.get('path') + '/' + this.model.get('name');
    return {
      href: "#folder" + path
    };
  };

  ConfigView.prototype.template = require('../templates/folder_line');

  return ConfigView;

})(BaseView);

});

;
//@ sourceMappingURL=app.js.map