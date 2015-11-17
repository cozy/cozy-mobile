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
var DeviceStatus, LayoutView, Notifications, Replicator, ServiceManager, log;

require('/lib/utils');

Replicator = require('./replicator/main');

LayoutView = require('./views/layout');

ServiceManager = require('./service/service_manager');

Notifications = require('../views/notifications');

DeviceStatus = require('./lib/device_status');

log = require('/lib/persistent_log')({
  prefix: "application",
  date: true,
  processusTag: "Application"
});

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
          var msg;
          if (err) {
            log.error(err);
            msg = err.message || err;
            msg += "\n " + (t('error try restart'));
            alert(msg);
            return navigator.app.exitApp();
          }
          if (!window.isBrowserDebugging) {
            _this.notificationManager = new Notifications();
            _this.serviceManager = new ServiceManager();
          }
          $('body').empty().append(_this.layout.render().$el);
          $('body').css('background-color', 'white');
          Backbone.history.start();
          DeviceStatus.initialize();
          if (config.remote) {
            if (!_this.replicator.config.has('checkpointed')) {
              log.info('Launch first replication again.');
              return app.router.navigate('first-sync', {
                trigger: true
              });
            } else {
              return app.regularStart();
            }
          } else {
            return _this.router.navigate('login', {
              trigger: true
            });
          }
        });
      };
    })(this));
  },
  regularStart: function() {
    var conf;
    app.foreground = true;
    conf = app.replicator.config.attributes;
    log.info("Start v" + (app.replicator.config.appVersion()) + "--sync_contacts:" + conf.syncContacts + ",sync_images:" + conf.syncImages + ",sync_on_wifi:" + conf.syncOnWifi + ",cozy_notifications:" + conf.cozyNotifications);
    document.addEventListener("resume", (function(_this) {
      return function() {
        log.info("RESUME EVENT");
        app.foreground = true;
        if (app.backFromOpen) {
          app.backFromOpen = false;
          return app.replicator.startRealtime();
        } else {
          return app.replicator.backup({}, function(err) {
            if (err) {
              return log.error(err);
            }
          });
        }
      };
    })(this), false);
    document.addEventListener("pause", (function(_this) {
      return function() {
        log.info("PAUSE EVENT");
        app.foreground = false;
        return app.replicator.stopRealtime();
      };
    })(this), false);
    document.addEventListener('online', function() {
      var backup;
      backup = function() {
        app.replicator.backup({}, function(err) {
          if (err) {
            return log.error(err);
          }
        });
        return window.removeEventListener('realtime:onChange', backup, false);
      };
      return window.addEventListener('realtime:onChange', backup, false);
    }, false);
    this.router.navigate('folder/', {
      trigger: true
    });
    return this.router.once('collectionfetched', (function(_this) {
      return function() {
        return app.replicator.backup({}, function(err) {
          if (err) {
            return log.error(err);
          }
        });
      };
    })(this));
  }
};

});

require.register("collections/files", function(exports, require, module) {
var File, FileAndFolderCollection, PAGE_LENGTH, log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

File = require('../models/file');

PAGE_LENGTH = 20;

log = require('/lib/persistent_log')({
  prefix: "files collections",
  date: true
});

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
          _this.allPagesLoaded = true;
          _this.trigger('sync');
          return callback(err);
        });
      };
    })(this));
  };

  FileAndFolderCollection.prototype.fetch = function(callback) {
    if (callback == null) {
      callback = function() {};
    }
    this.offset = 0;
    return this._fetchPathes(this.path, (function(_this) {
      return function(err, results) {
        _this.inPathIds = results.rows.map(function(row) {
          return row.id;
        });
        _this.loadNextPage(callback);
        return _this.trigger('fullsync');
      };
    })(this));
  };

  FileAndFolderCollection.prototype.loadNextPage = function(_callback) {
    var callback;
    callback = (function(_this) {
      return function(err, noMoreItems) {
        _this.notloaded = false;
        _this.trigger('sync');
        return _callback(err, noMoreItems);
      };
    })(this);
    return this._fetchNextPageDocs((function(_this) {
      return function(err, items) {
        var models;
        if (err) {
          return callback(err);
        }
        models = _this._rowsToModels(items);
        _this.allPagesLoaded = models.length < PAGE_LENGTH;
        if (_this.offset === 0) {
          _this.reset(models);
        } else {
          _this.add(models);
        }
        _this.offset += PAGE_LENGTH;
        return callback(err, _this.allPagesLoaded);
      };
    })(this));
  };

  FileAndFolderCollection.prototype._fetchPathes = function(path, callback) {
    var params, view;
    if (path === t('photos')) {
      params = {
        endkey: path ? ['/' + path] : [''],
        startkey: path ? ['/' + path, {}] : ['', {}],
        descending: true
      };
      view = 'Pictures';
    } else {
      params = {
        startkey: path ? ['/' + path] : [''],
        endkey: path ? ['/' + path, {}] : ['', {}]
      };
      view = 'FilesAndFolder';
    }
    return app.replicator.db.query(view, params, callback);
  };

  FileAndFolderCollection.prototype._fetchNextPageDocs = function(callback) {
    var ids, params;
    ids = this.inPathIds.slice(this.offset, this.offset + PAGE_LENGTH);
    params = {
      keys: ids,
      include_docs: true
    };
    return app.replicator.db.allDocs(params, callback);
  };

  FileAndFolderCollection.prototype._rowsToModels = function(results) {
    return results.rows.map(function(row) {
      var binary_id, doc, _ref, _ref1;
      doc = row.doc;
      if (doc.docType.toLowerCase() === 'file') {
        if (binary_id = (_ref = doc.binary) != null ? (_ref1 = _ref.file) != null ? _ref1.id : void 0 : void 0) {
          doc.incache = app.replicator.fileInFileSystem(doc);
          doc.version = app.replicator.fileVersion(doc);
        }
      } else if (doc.docType.toLowerCase() === 'folder') {
        doc.incache = false;
      }
      return doc;
    });
  };

  FileAndFolderCollection.prototype.slowReset = function(results, callback) {
    var i, models, nonBlockingAdd;
    models = this._rowsToModels(results);
    this.reset(models.slice(0, 10));
    if (models.length < 10) {
      return callback(null);
    }
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
              log.error(err);
            }
            folder.set('incache', incache);
            return setImmediate(cb);
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
          log.error(err);
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
var battery, callbackWaiting, callbacks, checkReadyForSync, log, onBatteryStatus, timeout;

log = require('/lib/persistent_log')({
  prefix: "device status",
  date: true
});

callbacks = [];

battery = null;

timeout = false;

callbackWaiting = function(err, ready, msg) {
  var callback, _i, _len;
  for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
    callback = callbacks[_i];
    callback(err, ready, msg);
  }
  return callbacks = [];
};

onBatteryStatus = (function(_this) {
  return function(newStatus) {
    timeout = false;
    battery = newStatus;
    return checkReadyForSync();
  };
})(this);

module.exports.initialize = function() {
  if (timeout || (battery != null)) {
    log.info("already initialized");
    return;
  }
  timeout = true;
  log.info("initialize device status.");
  return window.addEventListener('batterystatus', onBatteryStatus);
};

module.exports.shutdown = function() {
  return window.removeEventListener('batterystatus', onBatteryStatus);
};

module.exports.checkReadyForSync = checkReadyForSync = function(callback) {
  if (window.isBrowserDebugging) {
    return callback(null, true);
  }
  if (callback != null) {
    callbacks.push(callback);
  }
  if (battery == null) {
    setTimeout((function(_this) {
      return function() {
        if (timeout) {
          return callbackWaiting(new Error("No battery informations"));
        }
      };
    })(this), 4 * 1000);
    return;
  }
  if (!(battery.level > 20 || battery.isPlugged)) {
    log.info("NOT ready on battery low.");
    return callbackWaiting(null, false, 'no battery');
  }
  if (app.replicator.config.get('syncOnWifi') && (!(navigator.connection.type === Connection.WIFI))) {
    log.info("NOT ready on no wifi.");
    return callbackWaiting(null, false, 'no wifi');
  }
  log.info("ready to sync.");
  return callbackWaiting(null, true);
};

});

require.register("lib/persistent_log", function(exports, require, module) {
var LOG_SIZE, Logger, colors, levelColors,
  __slice = [].slice;

module.exports = function(options) {
  return new Logger(options);
};

LOG_SIZE = 500;

colors = {
  blue: ['\x1B[34m', '\x1B[39m'],
  cyan: ['\x1B[36m', '\x1B[39m'],
  green: ['\x1B[32m', '\x1B[39m'],
  magenta: ['\x1B[36m', '\x1B[39m'],
  red: ['\x1B[31m', '\x1B[39m'],
  yellow: ['\x1B[33m', '\x1B[39m']
};

levelColors = {
  error: colors.red,
  debug: colors.green,
  warn: colors.yellow,
  info: colors.blue
};

Logger = (function() {
  function Logger(options) {
    this.options = options;
    if (this.options == null) {
      this.options = {};
    }
    if ('processusTag' in this.options) {
      Logger.processusTag = this.options.processusTag;
    }
    if (typeof localStorage === "undefined" || localStorage === null) {
      this.noLog = true;
    }
  }

  Logger.prototype.stringify = function(text) {
    var err;
    if (text instanceof Error) {
      err = text;
      text = err.message;
      if (err.stack != null) {
        text += "\n" + err.stack;
      }
    } else if (text instanceof Object) {
      text = JSON.stringify(text);
    }
    return text;
  };

  Logger.prototype.format = function(level, texts) {
    var date, text;
    text = ((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = texts.length; _i < _len; _i++) {
        text = texts[_i];
        _results.push(this.stringify(text));
      }
      return _results;
    }).call(this)).join(" ");
    if (this.options.prefix != null) {
      text = "" + this.options.prefix + " | " + text;
    }
    if (level) {
      text = "" + level + " - " + text;
    }
    if (Logger.processusTag) {
      text = "" + Logger.processusTag + "> " + text;
    }
    if (this.options.date) {
      date = new Date().toISOString();
      text = "[" + date + "] " + text;
    }
    return text;
  };

  Logger.prototype.info = function() {
    var text, texts;
    texts = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.noLog) {
      return;
    }
    text = this.format('info', texts);
    this.persist(text);
    return console.info(text);
  };

  Logger.prototype.warn = function() {
    var text, texts;
    texts = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.noLog) {
      return;
    }
    text = this.format('warn', texts);
    this.persist(text);
    return console.warn(text);
  };

  Logger.prototype.error = function() {
    var text, texts;
    texts = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.noLog) {
      return;
    }
    text = this.format('error', texts);
    this.persist(text);
    return console.error(text);
  };

  Logger.prototype.debug = function() {
    var text, texts;
    texts = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.noLog) {
      return;
    }
    text = this.format('debug', texts);
    this.persist(text);
    return console.info(text);
  };

  Logger.prototype.raw = function() {
    var texts;
    texts = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.noLog) {
      return;
    }
    return console.log.apply(console, texts);
  };

  Logger.prototype.lineBreak = function(text) {
    if (this.noLog) {
      return;
    }
    text = Array(80).join("*");
    this.raw(text);
    return window.logTrace.push(text);
  };

  Logger.prototype.persist = function(text) {
    var logIndex;
    logIndex = +localStorage.getItem("log_index");
    logIndex = (logIndex + 1) % LOG_SIZE;
    localStorage.setItem("log_" + logIndex, text);
    return localStorage.setItem("log_index", '' + logIndex);
  };

  Logger.prototype.getTraces = function() {
    var i, log, logIndex, traces;
    logIndex = +localStorage.getItem("log_index");
    i = (logIndex + 1) % LOG_SIZE;
    traces = [];
    while (i !== logIndex) {
      log = localStorage.getItem("log_" + i);
      if (log) {
        traces.push(log);
      }
      i = (i + 1) % LOG_SIZE;
    }
    return traces;
  };

  return Logger;

})();

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
    // Fix cozy 2015-08-25 : escape to UTF8
    data = unescape(encodeURIComponent(data));

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

require.register("lib/utils", function(exports, require, module) {
window.setImmediate = window.setImmediate || function(callback) {
  return setTimeout(callback, 1);
};

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

require.register("locales/de", function(exports, require, module) {
module.exports = {
    "app name": "Cozy mobil",
    "cozy url": "Cozys Domain",
    "cozy password": "Cozys Passwort",
    "name device": "Name für das Gerat",
    "device name": "Gerätename",
    "search": "suche",
    "files": "Dateien",
    "config": "Einstellungen",
    "never": "Nie",
    "phone2cozy title": "Handy nach Cozy Backup",
    "contacts sync label": "Sync Kontakte",
    "images sync label": "Backup Bilder",
    "wifi sync label": "Backup nur über Wlan",
    "cozy notifications sync label": "Sync Cozy Benachrichtigungen ",
    "home": "Start",
    "about": "Über",
    "last backup": "Zuletzt war :",
    "reset title": "Reset",
    "reset action": "Reset",
    "retry synchro": "Sync",
    "synchro warning": "Alles neu synchronisiert. Es kann längere zeit dauern.",
    "reset warning": "Alle Cozy Daten auf deinem Handy löschen",
    "support": "Support",
    "send log": "Send",
    "send log info": "Send an email with application log to help us improve its quality and stability.",
    "send log please describe problem": "Please describe the problem:",
    "send log trace begin": "Log Trace: please don't touch (or tell us what)",
    "send log trace end": "END of Log Trace.",
    "pull to sync": "Ziehen für sync",
    "syncing": "Aktualisiert ",
    "contacts_sync": "Aktualisiere Kontakte",
    "contacts_sync_to_pouch": "Aktualisiere Kontakte",
    "contacts_sync_to_cozy": "Aktualisiere Kontakte",
    "contacts_sync_to_phone": "Aktualisiere Kontakte",
    "pictures_sync": "Aktualisiere Bilder",
    "cache_sync": "Updating cache",
    "destroying database": "Destroying database",
    "synchronized with": "Syncrnoisiert mit",
    "this folder is empty": "Dieser Ordner ist leer",
    "no results": "Keine Ergenisse",
    "loading": "Lädt",
    "remove local": "Lösche lokal",
    "download": "Download",
    "sync": "Aktualisieren",
    "backup": "Backup",
    "save": "Speichern",
    "done": "Fertig",
    "photos": "Bilder vom Handy",
    "confirm message": "Bist du sicher?",
    "confirm exit message": "Willst du wirklich Schließen?",
    "replication complete": "Abgleich abgeschlossen",
    "next": "Nächtes",
    "back": "zurück",
    "connection failure": "Verbindungsfehler",
    "setup 1/3": "Setup 1/3",
    "cozy welcome": "Welcome!",
    "cozy welcome message": "Cozy App enables you to: <ul><li>View your Files</li><li>Synchronize your Contacts</li><li>Backup your Photos</li></ul>",
    "cozy welcome no account": "If you don't already have a Cozy instance, visit <a target='_system' href='http://cozy.io/en/'>cozy.io</a> for more details.",
    "url placeholder": "dein Cozy Adresse",
    "password placeholder": "dein Passwort",
    "authenticating...": "Authenfizieren...",
    "setup 2/3": "Setup 2/3",
    "device name explanation": "Wähle einen namen für dein Smartphone um es einfach zu verwalten.",
    "device name placeholder": "mein-Handy",
    "registering...": "Registrieren...",
    "setup 3/3": "Setup 3/3",
    "setup end": "Ende der Einstellungen",
    "message step 0": "Step 1/5: Files synchronization.",
    "message step 1": "Step 2/5: Folders synchronization.",
    "message step 2": "Step 3/5: Notifications synchronization.",
    "message step 3": "Step 4/5: Contacts synchronization.",
    "message step 4": "Step 5/5: Documents preparation.",
    "wait message device": "Smartphone einrichtung...",
    "ready message": "Die App ist vollständig eingerichtet! Es kann los gehen.",
    "waiting...": "Warten...",
    "filesystem bug error": "Dateisystem Fehler. Versuche dein Handy neuzustarten",
    "end": "Ende",
    "please wait database migration": "Database update, please wait a few minutes…",
    "all fields are required": "Fülle alle Felder aus!",
    "cozy need patch": "Cozy braucht ein Update",
    "wrong password": "Passwort falsch",
    "device name already exist": "Gerätename existiert bereits",
    "An error happened (UNKNOWN)": "Ein Fehler ist aufgetreten",
    "An error happened (NOT FOUND)": "Ein Fehler ist aufgetreten.(Datei nicht gefunden)",
    "An error happened (INVALID URL)": "Ein Fehler ist aufgetreten.(Falsche URL)",
    "This file isnt available offline": "Diese Datei ist offline nicht verfügbar",
    "ABORTED": "Dieser Vorgang wurde abgebrochen",
    "photo folder not replicated yet": "Einrichtung ist noch nicht Abgeschlossen",
    "Not Found": "Fehler während der Einrichtung. hast du die Files App richtig installiert in deinem Cozy",
    "connexion error": "Die Verbindung zu deinem Cozy schlug fehl. Bitte überprüfe ob dein Smartphine mit dem Internet verbunden ist, die Cozy Adresse richtig ist und ob Cozy läuft. Für fortgeschrittene User mit eigener Cozy Installation überprüft  <a href='http://cozy.io/en/mobile/files.html#note-about-self-signed-certificates' target='_system'> für selbst signierte Zertifikate </a>",
    "no images in DCIM": "Backup Bilder: keine Bilder in dem DCIm Ordner.",
    "Document update conflict": "Update conflict in database, you could try to restart the app to fix it.",
    "Database not initialized. Confirm initialize": "Initialization didn't finish correctly. Retry ?",
    "no activity found": "Keine app für dieses dateiformat instaliet.",
    "not enough space": "Nicht genügend Speicher. Lösche Dateien aus dem Cache",
    "no battery": "Akku schwach. Backup abgebrochen",
    "no wifi": "Kein Wlan. Backup abgebrochen",
    "no connection": "Keine Verbindung. Backup abgebrochen",
    "bad credentials, did you enter an email address": "Bad credentials, did you enter an email address, instead of the url of your Cozy?",
    "error try restart": "Please try restarting the application."
};
});

require.register("locales/en", function(exports, require, module) {
module.exports = {
  "app name": "Cozy mobile",
  "cozy url": "Cozy's domain",
  "cozy password": "Cozy's password",
  "name device": "Name this device",
  "device name": "Device name",
  "search": "search",
  "files": "Files",
  "config": "Config",
  "never": "Never",
  "phone2cozy title": "Phone to Cozy backup",
  "contacts sync label": "Sync contacts",
  "images sync label": "Backup images",
  "wifi sync label": "Backup on Wifi only",
  "cozy notifications sync label": "Sync Cozy notifications",
  "home": "Home",
  "about": "About",
  "last backup": "Last was:",
  "reset title": "Reset",
  "reset action": "Reset",
  "retry synchro": "Sync",
  "synchro warning": "Launch a replication from the beginning. It may take a while.",
  "reset warning": "Erase all Cozy-generated data on your phone.",
  "support": "Support",
  "send log": "Send Log",
  "send log info": "Send an email with application log to help us improve its quality and stability.",
  "send log please describe problem": "Please describe the problem:",
  "send log trace begin": "Log Trace: please don't touch (or tell us what)",
  "send log trace end": "END of Log Trace.",
  "pull to sync": "Pull to sync",
  "syncing": "Syncing",
  "contacts_sync": "Syncing contacts",
  "contacts_sync_to_pouch": "Syncing contacts",
  "contacts_sync_to_cozy": "Syncing contacts",
  "contacts_sync_to_phone": "Syncing contacts",
  "pictures_sync": "Syncing pictures",
  "cache_sync": "Updating cache",
  "destroying database": "Destroying database",
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
  "photos": "Photos from devices",
  "confirm message": "Are you sure?",
  "confirm exit message": "Do you want to Exit?",
  "replication complete": "Replication complete",
  "next": "Next",
  "back": "Back",
  "connection failure": "Connection failure",
  "setup 1/3": "Setup 1/3",
  "cozy welcome": "Welcome!",
  "cozy welcome message": "Cozy App enables you to: <ul><li>View your Files</li><li>Synchronize your Contacts</li><li>Backup your Photos</li></ul>",
  "cozy welcome no account": "If you don't already have a Cozy instance, visit <a target='_system' href='http://cozy.io/en/'>cozy.io</a> for more details.",
  "url placeholder": "Your Cozy Address",
  "password placeholder": "Your Password",
  "authenticating...": "Authenticating...",
  "setup 2/3": "Setup 2/3",
  "device name explanation": "Choose a display name for this device so you can easily manage it.",
  "device name placeholder": "my-phone",
  "registering...": "Registering...",
  "setup 3/3": "Setup 3/3",
  "setup end": "End of setting",
  "message step 0": "Step 1/5: Files synchronization.",
  "message step 1": "Step 2/5: Folders synchronization.",
  "message step 2": "Step 3/5: Notifications synchronization.",
  "message step 3": "Step 4/5: Contacts synchronization.",
  "message step 4": "Step 5/5: Documents preparation.",
  "wait message device": "Device configuration...",
  "ready message": "The application is ready to be used!",
  "waiting...": "Waiting...",
  "filesystem bug error": "File system bug error. Try to restart your phone.",
  "end": "End",
  "please wait database migration": "Database update, please wait a few minutes…",
  "all fields are required": "All fields are required",
  "cozy need patch": "Cozy need patch",
  "wrong password": "Incorrect password",
  "device name already exist": "Device name already exist",
  "An error happened (UNKNOWN)": "An error occured.",
  "An error happened (NOT FOUND)": "An error occured (not found).",
  "An error happened (INVALID URL)": "An error occured (invalid url).",
  "This file isnt available offline": "This file isn't available offline.",
  "ABORTED": "The procedure was aborted.",
  "photo folder not replicated yet": "Initialization not finished yet.",
  "Not Found": "Error while initializing. Did you install the Files application in your Cozy ?",
  "connexion error": "We failed to connect to your cozy. Please check that your device is connected to the internet, the address of your cozy is spelled correctly and your cozy is running. If you are an advanced user with a self hosted cozy, refer to the <a href='http://cozy.io/en/mobile/files.html#note-about-self-signed-certificates' target='_system'>doc to handle self-signed certificates</a>.",
  "no images in DCIM": "Backup images : no image found in DCIM dir.",
  "Document update conflict": "Update conflict in database, you could try to restart the app to fix it.",
  "Database not initialized. Confirm initialize": "Initialization didn't finish correctly. Retry ?",
  "no activity found": "No application on phone for this kind of file.",
  "not enough space": "Not enough disk space, remove some files from cache.",
  "no battery": "Not enough battery, Backup cancelled.",
  "no wifi": "No Wifi, Backup cancelled.",
  "no connection": "No connection, Backup cancelled.",
  "bad credentials, did you enter an email address": "Bad credentials, did you enter an email address, instead of the url of your Cozy?",
  "error try restart": "Please try restarting the application."
}
;
});

require.register("locales/es", function(exports, require, module) {
module.exports = {
    "app name": "Cozy móvil",
    "cozy url": "Dirección de Cozy",
    "cozy password": "Contraseña",
    "name device": "Dar un nombre al periférico",
    "device name": "Nombre del periférico",
    "search": "buscar",
    "files": "Archivos",
    "config": "Configuración",
    "never": "Nunca",
    "phone2cozy title": "Hacer copia de seguridad del contenido del teléfono",
    "contacts sync label": "Sincronizar contactos",
    "images sync label": "Hacer copia de seguridad de las imágenes del teléfono",
    "wifi sync label": "Hacer copia de seguridad solamente si Wifi",
    "cozy notifications sync label": "Sincronizar las notificaciones Cozy",
    "home": "Escritorio",
    "about": "Acerca de",
    "last backup": "Último:",
    "reset title": "Reinicializar",
    "reset action": "Reinicializar",
    "retry synchro": "Sincronizar",
    "synchro warning": "Lanzar una réplica desde el comienzo. Puede tomar tiempo.",
    "reset warning": "Borrar de su teléfono todos los datos generados por Cozy.",
    "support": "Soporte",
    "send log": "Enviar Log",
    "send log info": "Enviar un email con el log de la aplicación para ayudarnos a mejorar su calidad y estabilidad.",
    "send log please describe problem": "Por favor, describa el problema:",
    "send log trace begin": "Traza del Log: por favor no toque (o díganos lo que hizo)",
    "send log trace end": "FIN de la Traza del Log.",
    "pull to sync": "Arrastrar para sincronizar",
    "syncing": "En curso de sincronización",
    "contacts_sync": "Sincronización de los contactos",
    "contacts_sync_to_pouch": "Sincronización de los contactos",
    "contacts_sync_to_cozy": "Sincronización de los contactos",
    "contacts_sync_to_phone": "Sincronización de los contactos",
    "pictures_sync": "Sincronización de las imágenes",
    "cache_sync": "Actualización de la cache",
    "destroying database": "Destruyendo la base de datos",
    "synchronized with": "Sincronizado con",
    "this folder is empty": "Esta carpeta está vacía",
    "no results": "No hay resultados",
    "loading": "Cargando",
    "remove local": "Suprimir del teléfono",
    "download": "Cargar",
    "sync": "Recargar",
    "backup": "Copia de seguridad",
    "save": "Guardar",
    "done": "Hecho",
    "photos": "Fotos desde los periféricos",
    "confirm message": "¿Está usted seguro(a)?",
    "confirm exit message": "¿Quiere usted salir de la aplicación?",
    "replication complete": "Reproducción terminada",
    "next": "Siguiente",
    "back": "Atrás",
    "connection failure": "Falla en la conexión",
    "setup 1/3": "Configuración 1/3",
    "cozy welcome": "¡Bienvenido(a)!",
    "cozy welcome message": "Cozy App le permite: <ul><li>Visualizar su Archivos</li><li>Sincronizar su Contactos</li><li>Hacer una copia de seguridad de su Fotos</li></ul>",
    "cozy welcome no account": "Si tusted no desea todavía una instancia Cozy, visite <a target='_system' href='http://cozy.io/en/'>cozy.io</a> para mayores detalles.",
    "url placeholder": "Su dirección Cozy",
    "password placeholder": "Su contraseña",
    "authenticating...": "Verificación de los identificadores...",
    "setup 2/3": "Configuración 2/3",
    "device name explanation": "Escoger un nombre para este periférico así se podrá administrar más facilmente.",
    "device name placeholder": "mi-teléfono",
    "registering...": "Registrando...",
    "setup 3/3": "Configuración 3/3",
    "setup end": "Fin de la configuración",
    "message step 0": "Paso 1/5: Sincronización de archivos",
    "message step 1": "Paso 2/5: Sincronización de carpetas.",
    "message step 2": "Paso 3/5: Notificaciones de sincronización.",
    "message step 3": "Paso 4/5: Sincronización de Contactos.",
    "message step 4": "Paso 5/5: Preparación de documentos.",
    "wait message device": "Configuración del periférico...",
    "ready message": "¡La aplicación está lista para su uso!",
    "waiting...": "En espera...",
    "filesystem bug error": "Error en el sistema de archivos. Tratar de reinicializar su teléfono.",
    "end": "Fin",
    "please wait database migration": "Actualización de la base de datos, por favor, espere algunos minutos...",
    "all fields are required": "Todas las casillas son obligatorias",
    "cozy need patch": "Cozy necesita un correctivo",
    "wrong password": "Contraseña incorrecta",
    "device name already exist": "Ese nombre de periférico ya existe",
    "An error happened (UNKNOWN)": "Un error ha ocurrido",
    "An error happened (NOT FOUND)": "Un error ha ocurrido (no identificado)",
    "An error happened (INVALID URL)": "Un error ha ocurrido (url inválida)",
    "This file isnt available offline": "Este archivo no está disponible fuera de línea.",
    "ABORTED": "El procedimiento se ha interrumpido.",
    "photo folder not replicated yet": "La inicialización aún no ha terminado.",
    "Not Found": "Error en la inicialización. ¿Ha usted instalado la aplicación Archivos en su Cozy?",
    "connexion error": "La conexión a su cozy ha fallado. Revisar que su periférico esté conectado a internet, que la dirección de su cozy esté bien escrita y si su cozy funciona. Para los usuarios avezados con cozy en sus propios servidores, consultar la <a href='http://cozy.io/en/mobile/files.html#note-about-self-signed-certificates' target='_system'>documentación sobre los certificados auto-firmados </a>",
    "no images in DCIM": "Copia de seguridad de imágenes: no se ha encontrado ninguna imagen en el directorio DCIM.",
    "Document update conflict": "Conflictos en la actualización de la base de datos. Usted podría reinicializar la aplicación para resoverlos.",
    "Database not initialized. Confirm initialize": "La inicialización no terminó correctamente. ¿Tratar de nuevo?",
    "no activity found": "Ninguna aplicación se ha encontrado en el teléfono para este tipo de archivos.",
    "not enough space": "No hay suficiente espacio disco en su teléfono.",
    "no battery": "La copia de seguridad no se hará ya que su teléfono no tiene suficiente batería.",
    "no wifi": "La copia de seguridad no se hará porque no hay conexión Wifi.",
    "no connection": "La copia de seguridad no se hará porque usted no está conectado.",
    "bad credentials, did you enter an email address": "Malas credenciales, ¿escribió usted su dirección email en lugar de la url de su Cozy?",
    "error try restart": "Please try restarting the application."
};
});

require.register("locales/fr", function(exports, require, module) {
module.exports = {
    "app name": "Cozy mobile",
    "cozy url": "Adresse Cozy",
    "cozy password": "Mot de passe",
    "name device": "Nom de l'appareil",
    "device name": "Nom de l'appareil",
    "search": "Recherche",
    "files": "Fichiers",
    "config": "Configuration",
    "never": "Jamais",
    "phone2cozy title": "Sauvegarde du téléphone",
    "contacts sync label": "Synchronisation des contacts",
    "images sync label": "Sauvegarde des images du téléphone",
    "wifi sync label": "Sauvegarde uniquement en Wifi",
    "cozy notifications sync label": "Synchroniser les notifications Cozy",
    "home": "Accueil",
    "about": "À propos",
    "last backup": "Derniere sauvegarde :",
    "reset title": "Remise à zéro",
    "reset action": "Remise à Zéro",
    "retry synchro": "Synchroniser",
    "synchro warning": "Relancer une synchronisation depuis le début. Cela peut prendre du temps.",
    "reset warning": "Relancer une synchronisation depuis le début. Cela peut prendre du temps.",
    "support": "Support",
    "send log": "Envoyer Journal",
    "send log info": "Envoyer un email avec le journal de l'application afin de nous aider à améliorer sa qualité et sa fiabilité.",
    "send log please describe problem": "Décrivez le problème que vous rencontrez s'il vous plait :",
    "send log trace begin": "Journal de l'application : ne le modifiez pas s'il vous plait (ou alors dites-nous ce que vous modifiez)",
    "send log trace end": "FIN du journal.",
    "pull to sync": "Tirer pour synchroniser",
    "syncing": "En cours de synchronisation",
    "contacts_sync": "Synchronisation des contacts",
    "contacts_sync_to_pouch": "Synchronisation des contacts",
    "contacts_sync_to_cozy": "Synchronisation des contacts",
    "contacts_sync_to_phone": "Synchronisation des contacts",
    "pictures_sync": "Synchronisation des images",
    "cache_sync": "Mise à jour du cache",
    "destroying database": "Destruction de la base de données",
    "synchronized with": "Synchronisé avec",
    "this folder is empty": "Ce dossier est vide.",
    "no results": "Pas de résultats",
    "loading": "Chargement",
    "remove local": "Supprimer du tél.",
    "download": "Télécharger",
    "sync": "Synchroniser",
    "backup": "Sauvegarder",
    "save": "Sauvegarder",
    "done": "Fait",
    "photos": "Appareils photo",
    "confirm message": "Êtes-vous sûr(e) ?",
    "confirm exit message": "Voulez-vous quitter l'application ?",
    "replication complete": "Reproduction terminée.",
    "next": "Suivant",
    "back": "Retour",
    "connection failure": "Échec de la connexion",
    "setup 1/3": "Configuration 1/3",
    "cozy welcome": "Bienvenue !",
    "cozy welcome message": "L'application Cozy vous permet de: <ul><li>Consulter vos Fichiers</li><li>Synchroniser vos Contacts</li><li>Sauvegarder vos Photos</li></ul>",
    "cozy welcome no account": "Si vous n'avez pas encore d'instance Cozy, rendez-vous sur <a target='_system' href='http://cozy.io/fr/'>cozy.io</a> pour en savoir plus.",
    "url placeholder": "Votre Adresse Cozy",
    "password placeholder": "Votre Mot de Passe",
    "authenticating...": "Vérification des identifiants…",
    "setup 2/3": "Configuration 2/3",
    "device name explanation": "Choisissez un nom d'usage pour ce périphérique  afin de le gérer facilement.",
    "device name placeholder": "mon-telephone",
    "registering...": "Enregistrement…",
    "setup 3/3": "Configuration 3/3",
    "setup end": "Fin de la configuration",
    "message step 0": "Etape 1/5 : Synchronisation des fichiers.",
    "message step 1": "Etape 2/5 : Synchronisation des dossiers.",
    "message step 2": "Etape 3/5 : Synchronisation des notifications.",
    "message step 3": "Etape 4/5 : Synchronisation des contacts.",
    "message step 4": "Etape 5/5 : Préparation des documents.",
    "wait message device": "Enregistrement de l'appareil…",
    "ready message": "L'application est prête à être utilisée !",
    "waiting...": "En attente…",
    "filesystem bug error": "Erreur dans le système de fichiers. Essayez de redémarrer votre téléphone",
    "end": "Fin",
    "please wait database migration": "Mise à jour du système de base de données, cela peut prendre quelques minutes…",
    "all fields are required": "Tous les champs sont obligatoires",
    "cozy need patch": "Cozy a besoin d'un correctif",
    "wrong password": "Mot de passe incorrect",
    "device name already exist": "Ce nom d'appareil existe déjà",
    "An error happened (UNKNOWN)": "Une erreur est survenue",
    "An error happened (NOT FOUND)": "Une erreur est survenue (non trouvé)",
    "An error happened (INVALID URL)": "Une erreur est survenue (url invalide)",
    "This file isnt available offline": "Ce fichier n'est pas disponible hors ligne",
    "ABORTED": "La procédure a été interrompue.",
    "photo folder not replicated yet": "L'initialisation n'est pas terminée.",
    "Not Found": "Erreur à l'initialisation. Avez-vous installé l'application Files sur votre Cozy ?",
    "connexion error": "La connection à votre cozy a échoué. Vérifiez que votre terminal est connecté à internet, que l'adresse de votre cozy est bien écrite et que votre cozy fonctionne. Pour les utilisateurs avancés avec un cozy auto-hébergé, consulter la <a href='http://cozy.io/fr/mobile/files.html#a-propos-des-certificats-auto-sign-s' target='_system'>documentation à propos des certificats autosignés</a>",
    "no images in DCIM": "Sauvegarde des images : aucune image trouvée dans le répertoire DCIM.",
    "Document update conflict": "Conflit lors d'une opération en base de données. Essayez de redémarrer l'application pour le résoudre.",
    "Database not initialized. Confirm initialize": "L'initialisation ne s'est pas déroulée correctement. Réessayer ?\"",
    "no activity found": "Aucune application n'a été trouvée sur ce téléphone pour ce type de fichier.",
    "not enough space": "Il n'y a pas suffisament d'espace disque sur votre mobile.",
    "no battery": "La sauvegarde n'aura pas lieu car vous n'avez pas assez de batterie.",
    "no wifi": "La sauvegarde n'aura pas lieu car vous n'êtes pas en wifi.",
    "no connection": "La sauvegarde n'aura pas lieu car vous n'avez pas de connexion.",
    "bad credentials, did you enter an email address": "Adresse ou mot de passe incorrect. Aviez-vous entré un email à la place de l'url de vorte Cozy ?",
  "error try restart": "Essayez de redémarrer l'application."

};
});

require.register("locales/ko", function(exports, require, module) {
module.exports = {
    "app name": "Cozy 모바일",
    "cozy url": "Cozy 도메인",
    "cozy password": "Cozy 비밀번호",
    "name device": "장치명",
    "device name": "장치명",
    "search": "검색",
    "files": "파일",
    "config": "설정",
    "never": "사용안함",
    "phone2cozy title": "모바일에서 Cozy로 백업",
    "contacts sync label": "연락처 동기화",
    "images sync label": "이미지 백업",
    "wifi sync label": "Wifi일 때 백업",
    "cozy notifications sync label": "Cozy 알림 동기화",
    "home": "홈",
    "about": "도움말",
    "last backup": "최근:",
    "reset title": "초기화",
    "reset action": "초기화",
    "retry synchro": "동기화",
    "synchro warning": "Launch a replication from the beginning. It may take a while.",
    "reset warning": "Erase all Cozy-generated data on your phone.",
    "support": "지원",
    "send log": "Send Log",
    "send log info": "앱 로그를 관리자에게 보내세요. 클라우드 성능 향상에 도움이 될 것입니다.",
    "send log please describe problem": "Please describe the problem:",
    "send log trace begin": "Log Trace: please don't touch (or tell us what)",
    "send log trace end": "END of Log Trace.",
    "pull to sync": "동기화 가져오기",
    "syncing": "동기화 중",
    "contacts_sync": "연락처 동기화 중",
    "contacts_sync_to_pouch": "연락처 동기화 중",
    "contacts_sync_to_cozy": "연락처 동기화 중",
    "contacts_sync_to_phone": "연락처 동기화 중",
    "pictures_sync": "사진 동기화",
    "cache_sync": "캐쉬 업데이트",
    "destroying database": "데이터베이스 삭제",
    "synchronized with": "와 동기화 됨",
    "this folder is empty": "이 폴더는 비어 있습니다.",
    "no results": "결과 없음",
    "loading": "불러오기",
    "remove local": "로컬 삭제",
    "download": "다운로드",
    "sync": "새로고침",
    "backup": "백업",
    "save": "저장",
    "done": "완료",
    "photos": "장치로 부터의 사진",
    "confirm message": "정말 실행 하시겠습니까?",
    "confirm exit message": "페이지를 나가시겠습니까?",
    "replication complete": "복제 완료",
    "next": "다음",
    "back": "뒤로",
    "connection failure": "연결 실패",
    "setup 1/3": "설정 1/3",
    "cozy welcome": "Welcome!",
    "cozy welcome message": "Cozy App enables you to: <ul><li>View your Files</li><li>Synchronize your Contacts</li><li>Backup your Photos</li></ul>",
    "cozy welcome no account": "If you don't already have a Cozy instance, visit <a target='_system' href='http://cozy.io/en/'>cozy.io</a> for more details.",
    "url placeholder": "Your Cozy Address",
    "password placeholder": "Your Password",
    "authenticating...": "인증 처리 중...",
    "setup 2/3": "설정 2/3",
    "device name explanation": "Choose a display name for this device so you can easily manage it.",
    "device name placeholder": "내 휴대폰",
    "registering...": "등록 중...",
    "setup 3/3": "설정 3/3",
    "setup end": "설정 완료",
    "message step 0": "단계 1/5 : 파일 동기화",
    "message step 1": "단계 2/5 : 폴더 동기화",
    "message step 2": "단계 3/5 : 알림 동기화",
    "message step 3": "단계 4/5 : 연락처 동기화",
    "message step 4": "단계 5/5 : 문서 준비",
    "wait message device": "장치 설정...",
    "ready message": "앱이 준비 되었습니다!",
    "waiting...": "기다려 주세요...",
    "filesystem bug error": "파일 시스템 버그. 휴대폰을 다시 시작해 주세요.",
    "end": "완료",
    "please wait database migration": "Database update, please wait a few minutes…",
    "all fields are required": "모든 항목이 필수 입니다.",
    "cozy need patch": "패치 필요",
    "wrong password": "잘못된 비밀번호",
    "device name already exist": "장치명이 이미 존재 합니다.",
    "An error happened (UNKNOWN)": "오류 발생.",
    "An error happened (NOT FOUND)": "오류 발생 (알 수 없음).",
    "An error happened (INVALID URL)": "오류 발생 (URL 오류).",
    "This file isnt available offline": "이 파일은 오프라인에서 사용 할 수 없습니다.",
    "ABORTED": "설치가 취소 되었습니다.",
    "photo folder not replicated yet": "초기화가 아직 완료 되지 않았습니다.",
    "Not Found": "초기화 중 오류. 클라우드에 파일 관련 앱을 설치 하였습니까?",
    "connexion error": "클라우드에 연결 하지 못했습니다. 인터넷 연결 상태, 접속 URL, 클라우드 실행 상태를 확인 하세요.  <a href='http://cozy.io/en/mobile/files.html#note-about-self-signed-certificates' target='_system'>참고 문서</a>",
    "no images in DCIM": "백업 이미지 : DCIM 디렉터리에 이미지가 없습니다.",
    "Document update conflict": "데이터 베이스 업데이트 충돌, 처리 후 앱을 다시 시작 하세요.",
    "Database not initialized. Confirm initialize": "Initialization didn't finish correctly. Retry ?",
    "no activity found": "이런 종류의 파일을 위한 앱이 없습니다.",
    "not enough space": "디스크 용량이 부족해서, 임시 파일을 삭제 합니다.",
    "no battery": "배터리가 부족으로, 백업이 취소 되었습니다.",
    "no wifi": "무선 네트워크 연결 안되어서, 백업이 취소 되었습니다.",
    "no connection": "네트워크 연결이 안되서, 백업이 취소 되었습니다.",
    "bad credentials, did you enter an email address": "Bad credentials, did you enter an email address, instead of the url of your Cozy?",
    "error try restart": "Please try restarting the application."
};
});

require.register("models/contact", function(exports, require, module) {
var Contact, log;

log = require('../lib/persistent_log')({
  prefix: "contact",
  date: true
});

module.exports = Contact = {
  _n2ContactName: function(n) {
    var familyName, formatted, givenName, middle, parts, prefix, suffix, validParts;
    if (n == null) {
      return void 0;
    }
    parts = n.split(';');
    familyName = parts[0], givenName = parts[1], middle = parts[2], prefix = parts[3], suffix = parts[4];
    validParts = parts.filter(function(part) {
      return (part != null) && part !== '';
    });
    formatted = validParts.join(' ');
    return new ContactName(formatted, familyName, givenName, middle, prefix, suffix);
  },
  _cozyContact2ContactOrganizations: function(contact) {
    if (contact.org) {
      return [new ContactOrganization(false, null, contact.org, contact.department, contact.title)];
    } else {
      return [];
    }
  },
  _cozyContact2URLs: function(contact) {
    if (contact.url && !contact.datapoints.some(function(dp) {
      return dp.type === "url" && dp.value === contact.url;
    })) {
      return [new ContactField('other', contact.url, false)];
    } else {
      return [];
    }
  },
  _tags2Categories: function(tags) {
    if (tags) {
      return tags.map(function(tag) {
        return new ContactField('categories', tag, false);
      });
    } else {
      return [];
    }
  },
  _attachments2Photos: function(contact) {
    var photo;
    if ((contact._attachments != null) && 'picture' in contact._attachments) {
      photo = new ContactField('base64', contact._attachments.picture.data);
      return [photo];
    }
    return [];
  },
  _adr2ContactAddress: function(datapoint) {
    var countryPart, formatted, street, structuredToFlat;
    if (datapoint.value instanceof Array) {
      structuredToFlat = function(t) {
        t = t.filter(function(part) {
          return (part != null) && part !== '';
        });
        return t.join(', ');
      };
      street = structuredToFlat(datapoint.value.slice(0, 3));
      countryPart = structuredToFlat(datapoint.value.slice(3, 7));
      formatted = street;
      if (countryPart !== '') {
        formatted += '\n' + countryPart;
      }
      return new ContactAddress(void 0, datapoint.type, formatted, street, datapoint.value[3], datapoint.value[4], datapoint.value[5], datapoint.value[6]);
    } else if (typeof datapoint.value === 'string') {
      return new ContactAddress(void 0, datapoint.type, datapoint.value, datapoint.value);
    } else {
      log.warning('adr datapoint has bad type');
      return new ContactAddress(void 0, datapoint.type, '');
    }
  },
  _dataPoints2Cordova: function(cozyContact, cordovaContact) {
    var addContactField, datapoint, i, name, _ref, _results;
    addContactField = function(cordovaField, datapoint) {
      var field;
      if (!cordovaContact[cordovaField]) {
        cordovaContact[cordovaField] = [];
      }
      field = new ContactField(datapoint.type, datapoint.value);
      return cordovaContact[cordovaField].push(field);
    };
    _ref = cozyContact.datapoints;
    _results = [];
    for (i in _ref) {
      datapoint = _ref[i];
      name = datapoint.name.toUpperCase();
      switch (name) {
        case 'TEL':
          _results.push(addContactField('phoneNumbers', datapoint));
          break;
        case 'EMAIL':
          _results.push(addContactField('emails', datapoint));
          break;
        case 'ADR':
          if (!cordovaContact.addresses) {
            cordovaContact.addresses = [];
          }
          _results.push(cordovaContact.addresses.push(this._adr2ContactAddress(datapoint)));
          break;
        case 'CHAT':
          _results.push(addContactField('ims', datapoint));
          break;
        case 'SOCIAL':
        case 'URL':
          _results.push(addContactField('urls', datapoint));
          break;
        case 'ABOUT':
          _results.push(addContactField('about', datapoint));
          break;
        case 'RELATION':
          _results.push(addContactField('relations', datapoint));
          break;
        default:
          _results.push(void 0);
      }
    }
    return _results;
  },
  _cozy2CordovaOptions: function(cozyContact) {
    var cordovaContact;
    cordovaContact = {
      displayName: cozyContact.fn,
      name: Contact._n2ContactName(cozyContact.n),
      nickname: cozyContact.nickname,
      organizations: Contact._cozyContact2ContactOrganizations(cozyContact),
      birthday: cozyContact.bday,
      urls: Contact._cozyContact2URLs(cozyContact),
      note: cozyContact.note,
      categories: Contact._tags2Categories(cozyContact.tags),
      photos: Contact._attachments2Photos(cozyContact),
      sourceId: cozyContact._id,
      sync2: cozyContact._rev,
      dirty: false,
      deleted: false
    };
    Contact._dataPoints2Cordova(cozyContact, cordovaContact);
    if (!cordovaContact.displayName) {
      cordovaContact.displayName = "--";
    }
    return cordovaContact;
  },
  cozy2Cordova: function(cozyContact) {
    return navigator.contacts.create(Contact._cozy2CordovaOptions(cozyContact));
  },
  _contactName2N: function(contactName) {
    var field, n, parts, _i, _len, _ref;
    if (contactName == null) {
      return void 0;
    }
    parts = [];
    _ref = ['familyName', 'givenName', 'middleName', 'honorificPrefix', 'honorificSuffix'];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      field = _ref[_i];
      parts.push(contactName[field] || '');
    }
    n = parts.join(';');
    if (n !== ';;;;') {
      return n;
    }
  },
  _categories2Tags: function(categories) {
    if (categories != null) {
      return categories.map(function(categorie) {
        return category.value;
      });
    }
  },
  _organizations2Cozy: function(organizations, cozyContact) {
    var organization;
    if ((organizations != null ? organizations.length : void 0) > 0) {
      organization = organizations[0];
      cozyContact.org = organization.name;
      cozyContact.department = organization.department;
      return cozyContact.title = organization.title;
    }
  },
  _cordova2Datapoints: function(cordovaContact, cozyContact) {
    var datapoints, field2Name, fieldName, fields, fieldsDatapoints, name, _ref, _ref1;
    datapoints = [];
    field2Name = {
      'phoneNumbers': 'tel',
      'emails': 'email',
      'ims': 'chat',
      'about': 'about',
      'relations': 'relation'
    };
    for (fieldName in field2Name) {
      name = field2Name[fieldName];
      fields = cordovaContact[fieldName];
      if ((fields != null ? fields.length : void 0) > 0) {
        fieldsDatapoints = fields.map(function(contactField) {
          return {
            name: name,
            type: contactField.type,
            value: contactField.value
          };
        });
        datapoints = datapoints.concat(fieldsDatapoints);
      }
    }
    if (((_ref = cordovaContact.addresses) != null ? _ref.length : void 0) > 0) {
      fieldsDatapoints = cordovaContact.addresses.map(function(contactAddress) {
        return {
          name: 'adr',
          type: contactAddress.type,
          value: ['', '', contactAddress.formatted, '', '', '', '']
        };
      });
      datapoints = datapoints.concat(fieldsDatapoints);
    }
    if (((_ref1 = cordovaContact.urls) != null ? _ref1.length : void 0) > 0) {
      fieldsDatapoints = cordovaContact.urls.map(function(contactField) {
        return {
          name: 'url',
          type: contactField.type,
          value: contactField.value
        };
      });
      datapoints = datapoints.concat(fieldsDatapoints);
    }
    return cozyContact.datapoints = datapoints;
  },
  cordova2Cozy: function(cordovaContact, callback) {
    var cozyContact, img, photo, _ref;
    cozyContact = {
      docType: 'contact',
      _id: cordovaContact.sourceId,
      id: cordovaContact.sourceId,
      _rev: cordovaContact.sync2,
      fn: cordovaContact.displayName,
      n: Contact._contactName2N(cordovaContact.name),
      bday: cordovaContact.birthday,
      nickname: cordovaContact.nickname,
      revision: new Date().toISOString(),
      note: cordovaContact.note,
      tags: Contact._categories2Tags(cordovaContact.categories)
    };
    Contact._organizations2Cozy(cordovaContact.organizations, cozyContact);
    Contact._cordova2Datapoints(cordovaContact, cozyContact);
    if (!(((_ref = cordovaContact.photos) != null ? _ref.length : void 0) > 0)) {
      return callback(null, cozyContact);
    }
    photo = cordovaContact.photos[0];
    if (photo.type === 'base64') {
      cozyContact._attachments = {
        picture: {
          content_type: 'application/octet-stream',
          data: photo.value
        }
      };
      return callback(null, cozyContact);
    } else if (photo.type === 'url') {
      img = new Image();
      img.onload = function() {
        var IMAGE_DIMENSION, canvas, ctx, dataUrl, ratio, ratiodim;
        IMAGE_DIMENSION = 600;
        ratiodim = img.width > img.height ? 'height' : 'width';
        ratio = IMAGE_DIMENSION / img[ratiodim];
        canvas = document.createElement('canvas');
        canvas.height = canvas.width = IMAGE_DIMENSION;
        ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, ratio * img.width, ratio * img.height);
        dataUrl = canvas.toDataURL('image/jpeg');
        cozyContact._attachments = {
          picture: {
            content_type: 'application/octet-stream',
            data: dataUrl.split(',')[1]
          }
        };
        return callback(null, cozyContact);
      };
      return img.src = photo.value;
    }
  }
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
var DOWNLOADS_FOLDER, basic, fs, getFileSystem, log, readable, __chromeSafe;

basic = require('../lib/basic');

DOWNLOADS_FOLDER = 'cozy-downloads';

log = require('/lib/persistent_log')({
  prefix: "replicator mapreduce",
  date: true
});

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
    if (!(code === err.code)) {
      continue;
    }
    err.message = 'File error: ' + name.replace('_ERR', '').replace('_', ' ');
    return err;
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
          return log.info("NOMEDIA FILE CREATED");
        }, function() {
          return log.info("NOMEDIA FILE NOT CREATED");
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

module.exports.moveTo = function(entry, directory, name, callback) {
  var onError, onSuccess;
  onSuccess = function(entry) {
    return callback(null, entry);
  };
  onError = function(err) {
    return callback(err);
  };
  return entry.moveTo(directory, name, null, onSuccess, onError);
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
    return callback(readable(err));
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
    return callback(readable(err));
  };
  return reader.readEntries(onSuccess, onError);
};

module.exports.rmrf = function(directory, callback) {
  var onError, onSuccess;
  onError = function(err) {
    return callback(readable(err));
  };
  onSuccess = function() {
    return callback(null);
  };
  return directory.removeRecursively(onSuccess, onError);
};

module.exports.freeSpace = function(callback) {
  var onError, onSuccess;
  onError = function(err) {
    return callback(readable(err));
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
    return callback(readable(err));
  };
  return resolveLocalFileSystemURL('file://' + path, onSuccess, onError);
};

module.exports.fileFromEntry = function(entry, callback) {
  var onError, onSuccess;
  onSuccess = function(file) {
    return callback(null, file);
  };
  onError = function(err) {
    return callback(readable(err));
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
    return callback(readable(err));
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
var DBNAME, DBOPTIONS, DBPHOTOS, DeviceStatus, Replicator, ReplicatorConfig, fs, log, makeDesignDocs, request,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

request = require('../lib/request');

fs = require('./filesystem');

makeDesignDocs = require('./replicator_mapreduce');

ReplicatorConfig = require('./replicator_config');

DeviceStatus = require('../lib/device_status');

DBNAME = "cozy-files.db";

DBPHOTOS = "cozy-photos.db";

DBOPTIONS = {
  adapter: 'idb'
};

log = require('/lib/persistent_log')({
  prefix: "replicator",
  date: true
});

module.exports = Replicator = (function(_super) {
  var realtimeBackupCoef;

  __extends(Replicator, _super);

  function Replicator() {
    this.syncCache = __bind(this.syncCache, this);
    this.stopRealtime = __bind(this.stopRealtime, this);
    this.startRealtime = __bind(this.startRealtime, this);
    this.updateLocal = __bind(this.updateLocal, this);
    this.folderInFileSystem = __bind(this.folderInFileSystem, this);
    this.fileVersion = __bind(this.fileVersion, this);
    this.fileInFileSystem = __bind(this.fileInFileSystem, this);
    return Replicator.__super__.constructor.apply(this, arguments);
  }

  Replicator.prototype.db = null;

  Replicator.prototype.config = null;

  _.extend(Replicator.prototype, require('./replicator_backups'));

  _.extend(Replicator.prototype, require('./replicator_contacts'));

  _.extend(Replicator.prototype, require('./replicator_migration'));

  Replicator.prototype.defaults = function() {
    return {
      inSync: false,
      inBackup: false
    };
  };

  Replicator.prototype.init = function(callback) {
    return fs.initialize((function(_this) {
      return function(err, downloads, cache) {
        if (err) {
          return callback(err);
        }
        _this.downloads = downloads;
        _this.cache = cache;
        _this.db = new PouchDB(DBNAME, DBOPTIONS);
        _this.photosDB = new PouchDB(DBPHOTOS, DBOPTIONS);
        return _this.migrateDBs(function(err) {
          if (err) {
            return callback(err);
          }
          return makeDesignDocs(_this.db, _this.photosDB, function(err) {
            if (err) {
              return callback(err);
            }
            _this.config = new ReplicatorConfig(_this);
            return _this.config.fetch(callback);
          });
        });
      };
    })(this));
  };

  Replicator.prototype.destroyDB = function(callback) {
    return this.db.destroy((function(_this) {
      return function(err) {
        if (err) {
          return callback(err);
        }
        return _this.photosDB.destroy(function(err) {
          if (err) {
            return callback(err);
          }
          return fs.rmrf(_this.downloads, callback);
        });
      };
    })(this));
  };

  Replicator.prototype.checkCredentials = function(config, callback) {
    return request.post({
      uri: "" + (this.config.getScheme()) + "://" + config.cozyURL + "/login",
      json: {
        username: 'owner',
        password: config.password
      }
    }, function(err, response, body) {
      var error;
      if (err) {
        if (config.cozyURL.indexOf('@') !== -1) {
          error = t('bad credentials, did you enter an email address');
        } else {
          log.error(err);
          return callback(err.message);
        }
      } else if ((response != null ? response.status : void 0) === 0) {
        error = t('connexion error');
      } else if ((response != null ? response.statusCode : void 0) !== 200) {
        error = (err != null ? err.message : void 0) || body.error || body.message;
      } else {
        error = null;
      }
      return callback(error);
    });
  };

  Replicator.prototype.registerRemote = function(config, callback) {
    return request.post({
      uri: "" + (this.config.getScheme()) + "://" + config.cozyURL + "/device/",
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
            fullRemoteURL: ("" + (_this.config.getScheme()) + "://" + config.deviceName + ":" + body.password) + ("@" + config.cozyURL + "/cozy")
          });
          return _this.config.save(config, callback);
        }
      };
    })(this));
  };

  Replicator.prototype.initialReplication = function(callback) {
    this.set('initialReplicationStep', 0);
    return DeviceStatus.checkReadyForSync((function(_this) {
      return function(err, ready, msg) {
        var options;
        if (err) {
          return callback(err);
        }
        if (!ready) {
          return callback(new Error(msg));
        }
        log.info("enter initialReplication");
        _this.stopRealtime();
        options = _this.config.makeUrl('/_changes?descending=true&limit=1');
        return request.get(options, function(err, res, body) {
          var last_seq;
          if (err) {
            return callback(err);
          }
          last_seq = body.last_seq;
          return async.series([
            function(cb) {
              return _this.copyView('file', cb);
            }, function(cb) {
              return _this.set('initialReplicationStep', 1) && cb(null);
            }, function(cb) {
              return _this.copyView('folder', cb);
            }, function(cb) {
              return _this.set('initialReplicationStep', 2) && cb(null);
            }, function(cb) {
              if (_this.config.get('cozyNotifications')) {
                return _this.copyView('notification', cb);
              } else {
                return cb();
              }
            }, function(cb) {
              return _this.set('initialReplicationStep', 3) && cb(null);
            }, function(cb) {
              return _this.initContactsInPhone(last_seq, cb);
            }, function(cb) {
              return _this.set('initialReplicationStep', 4) && cb(null);
            }, function(cb) {
              return _this.config.save({
                checkpointed: last_seq
              }, cb);
            }, function(cb) {
              return _this.db.query('FilesAndFolder', {}, cb);
            }, function(cb) {
              return _this.db.query('NotificationsTemporary', {}, cb);
            }
          ], function(err) {
            log.info("end of inital replication");
            _this.set('initialReplicationStep', 5);
            callback(err);
            return _this.updateIndex(function() {
              return log.info("Index built");
            });
          });
        });
      };
    })(this));
  };

  Replicator.prototype.copyView = function(model, callback) {
    var handleResponse, options, options2;
    log.info("enter copyView for " + model + ".");
    if (model === 'file' || model === 'folder') {
      options = this.config.makeUrl("/_design/" + model + "/_view/files-all/");
      options2 = this.config.makeUrl("/_design/" + model + "/_view/all/");
    } else if (model === 'notification') {
      options = this.config.makeUrl("/_design/" + model + "/_view/all/");
      options2 = this.config.makeUrl("/_design/" + model + "/_view/byDate/");
    } else {
      options = this.config.makeUrl("/_design/" + model + "/_view/all/");
    }
    handleResponse = (function(_this) {
      return function(err, res, body) {
        var _ref;
        if (!err && res.status > 399) {
          log.info("Unexpected response: " + res);
          err = new Error(res.statusText);
        }
        if (err) {
          return callback(err);
        }
        if (!((_ref = body.rows) != null ? _ref.length : void 0)) {
          return callback(null);
        }
        return async.eachSeries(body.rows, function(doc, cb) {
          doc = doc.value;
          return _this.db.put(doc, {
            'new_edits': false
          }, function(err, file) {
            return cb();
          });
        }, callback);
      };
    })(this);
    return request.get(options, function(err, res, body) {
      if (res.status === 404 && (model === 'file' || model === 'folder' || model === 'notification')) {
        return request.get(options2, handleResponse);
      } else {
        return handleResponse(err, res, body);
      }
    });
  };

  Replicator.prototype.updateIndex = function(callback) {
    return this.db.search({
      build: true,
      fields: ['name']
    }, (function(_this) {
      return function(err) {
        log.info("INDEX BUILT");
        if (err) {
          log.warn(err);
        }
        return _this.db.query('FilesAndFolder', {}, function() {
          return _this.db.query('LocalPath', {}, function() {
            return callback(null);
          });
        });
      };
    })(this));
  };

  Replicator.prototype.fileToEntryName = function(file) {
    return file.binary.file.id + '-' + file.binary.file.rev;
  };

  Replicator.prototype.fileInFileSystem = function(file) {
    if (file.docType.toLowerCase() === 'file') {
      return this.cache.some(function(entry) {
        return entry.name.indexOf(file.binary.file.id) !== -1;
      });
    }
  };

  Replicator.prototype.fileVersion = function(file) {
    if (file.docType.toLowerCase() === 'file') {
      return this.cache.some((function(_this) {
        return function(entry) {
          return entry.name === _this.fileToEntryName(file);
        };
      })(this));
    }
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

  Replicator.prototype.removeFromCacheList = function(entryName) {
    var currentEntry, index, _i, _len, _ref, _results;
    _ref = this.cache;
    _results = [];
    for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
      currentEntry = _ref[index];
      if (!(currentEntry.name === entryName)) {
        continue;
      }
      this.cache.splice(index, 1);
      break;
    }
    return _results;
  };

  Replicator.prototype.getBinary = function(model, progressback, callback) {
    return fs.getOrCreateSubFolder(this.downloads, this.fileToEntryName(model), (function(_this) {
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
          options = _this.config.makeUrl("/" + model.binary.file.id + "/file");
          options.path = binfolder.toURL() + '/' + model.name;
          log.info("download binary of " + model.name);
          return fs.download(options, progressback, function(err, entry) {
            var found;
            if (((err != null ? err.message : void 0) != null) && err.message === "This file isnt available offline" && _this.fileInFileSystem(model)) {
              found = false;
              _this.cache.some(function(entry) {
                if (entry.name.indexOf(binary_id) !== -1) {
                  found = true;
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
              callback(null, entry.toURL());
              return _this.removeAllLocal(model, function() {});
            }
          });
        });
      };
    })(this));
  };

  Replicator.prototype.removeAllLocal = function(file, callback) {
    var id;
    return id = async.eachSeries(this.cache, (function(_this) {
      return function(entry, cb) {
        if (entry.name.indexOf(file.binary.file.id) !== -1 && entry.name !== _this.fileToEntryName(file)) {
          return fs.getDirectory(_this.downloads, entry.name, function(err, binfolder) {
            if (err) {
              return cb(err);
            }
            return fs.rmrf(binfolder, function(err) {
              _this.removeFromCacheList(entry.name);
              return cb();
            });
          });
        } else {
          return cb();
        }
      };
    })(this), callback);
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
            log.warn('not enough space');
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
              pb = reportProgress.bind(null, file._id);
              return _this.getBinary(file, pb, cb);
            }, callback);
          }
        });
      };
    })(this));
  };

  Replicator.prototype.getDbFilesOfFolder = function(folder, callback) {
    var options, path;
    path = folder.path;
    path += '/' + folder.name;
    options = {
      startkey: [path],
      endkey: [path + '/\uffff', {}],
      include_docs: true
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

  Replicator.prototype.updateLocal = function(options, callback) {
    var entry, file, noop;
    file = options.file;
    entry = options.entry;
    noop = function() {};
    if (file._deleted) {
      return this.removeLocal(file, callback);
    } else if (entry.name !== this.fileToEntryName(file)) {
      return DeviceStatus.checkReadyForSync((function(_this) {
        return function(err, ready, msg) {
          if (err) {
            return callback(err);
          }
          if (ready) {
            return _this.getBinary(file, noop, callback);
          } else {
            return callback(new Error(msg));
          }
        };
      })(this));
    } else {
      return fs.getChildren(entry, (function(_this) {
        return function(err, children) {
          if (err) {
            return callback(err);
          }
          if (children.length === 0) {
            log.warn("Missing file " + file.name + " on device, fetching it.");
            return _this.getBinary(file, noop, callback);
          } else if (children[0].name === file.name) {
            return callback();
          } else {
            return fs.moveTo(children[0], entry, file.name, callback);
          }
        };
      })(this));
    }
  };

  Replicator.prototype.removeLocal = function(file, callback) {
    log.info("remove " + file.name + " from cache.");
    return fs.getDirectory(this.downloads, this.fileToEntryName(file), (function(_this) {
      return function(err, binfolder) {
        if (err) {
          return callback(err);
        }
        return fs.rmrf(binfolder, function(err) {
          _this.removeFromCacheList(_this.fileToEntryName(file));
          return callback(err);
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

  Replicator.prototype._filesNEntriesInCache = function(docs) {
    var entries, file, fileNEntriesInCache, _i, _len;
    fileNEntriesInCache = [];
    for (_i = 0, _len = docs.length; _i < _len; _i++) {
      file = docs[_i];
      if (file.docType.toLowerCase() === 'file' && (file.binary != null)) {
        entries = this.cache.filter(function(entry) {
          return entry.name.indexOf(file.binary.file.id) !== -1;
        });
        if (entries.length !== 0) {
          fileNEntriesInCache.push({
            file: file,
            entry: entries[0]
          });
        }
      }
    }
    return fileNEntriesInCache;
  };

  Replicator.prototype._replicationFilter = function() {
    var filter;
    if (this.config.get('cozyNotifications')) {
      filter = function(doc) {
        var _ref, _ref1, _ref2, _ref3;
        return ((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'folder' || ((_ref1 = doc.docType) != null ? _ref1.toLowerCase() : void 0) === 'file' || ((_ref2 = doc.docType) != null ? _ref2.toLowerCase() : void 0) === 'notification' && ((_ref3 = doc.type) != null ? _ref3.toLowerCase() : void 0) === 'temporary';
      };
    } else {
      filter = function(doc) {
        var _ref, _ref1;
        return ((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'folder' || ((_ref1 = doc.docType) != null ? _ref1.toLowerCase() : void 0) === 'file';
      };
    }
    return filter;
  };

  Replicator.prototype.sync = function(options, callback) {
    if (this.get('inSync')) {
      return callback(null);
    }
    if (!this.config.has('checkpointed')) {
      return callback(new Error("database not initialized"));
    }
    log.info("start a sync");
    this.set('inSync', true);
    return this._sync(options, (function(_this) {
      return function(err) {
        _this.set('inSync', false);
        return callback(err);
      };
    })(this));
  };

  Replicator.prototype._sync = function(options, callback) {
    var changedDocs, checkpoint, replication, total_count;
    total_count = 0;
    this.stopRealtime();
    changedDocs = [];
    checkpoint = this.config.get('checkpointed');
    replication = this.db.replicate.from(this.config.remote, {
      batch_size: 20,
      batches_limit: 5,
      filter: this._replicationFilter(),
      live: false,
      since: checkpoint
    });
    replication.on('change', (function(_this) {
      return function(change) {
        log.info("changes received while sync");
        return changedDocs = changedDocs.concat(change.docs);
      };
    })(this));
    replication.once('error', (function(_this) {
      return function(err) {
        var _ref;
        log.error("error while replication in sync", err);
        if (((err != null ? (_ref = err.result) != null ? _ref.status : void 0 : void 0) != null) && err.result.status === 'aborted') {
          if (replication != null) {
            replication.cancel();
          }
          return _this._sync(options, callback);
        } else {
          return callback(err);
        }
      };
    })(this));
    return replication.once('complete', (function(_this) {
      return function(result) {
        log.info("replication in sync completed.");
        return async.eachSeries(_this._filesNEntriesInCache(changedDocs), _this.updateLocal, function(err) {
          if (err) {
            log.warn(err);
          }
          return _this.config.save({
            checkpointed: result.last_seq
          }, function(err) {
            callback(err);
            if (!options.background) {
              app.router.forceRefresh();
              return _this.updateIndex(function() {
                return _this.startRealtime();
              });
            }
          });
        });
      };
    })(this));
  };

  realtimeBackupCoef = 1;

  Replicator.prototype.startRealtime = function() {
    if (this.liveReplication || !app.foreground) {
      return;
    }
    if (!this.config.has('checkpointed')) {
      log.error(new Error("database not initialized"));
      if (confirm(t('Database not initialized. Do it now ?'))) {
        app.router.navigate('first-sync', {
          trigger: true
        });
      }
      return;
    }
    log.info('REALTIME START');
    this.liveReplication = this.db.replicate.from(this.config.remote, {
      batch_size: 20,
      batches_limit: 5,
      filter: this._replicationFilter(),
      since: this.config.get('checkpointed'),
      continuous: true
    });
    this.liveReplication.on('change', (function(_this) {
      return function(change) {
        var event, fileNEntriesInCache;
        realtimeBackupCoef = 1;
        event = new Event('realtime:onChange');
        window.dispatchEvent(event);
        _this.set('inSync', true);
        fileNEntriesInCache = _this._filesNEntriesInCache(change.docs);
        return async.eachSeries(fileNEntriesInCache, _this.updateLocal, function(err) {
          if (err) {
            return log.error(err);
          } else {
            return log.info("updated binary in realtime");
          }
        });
      };
    })(this));
    this.liveReplication.on('uptodate', (function(_this) {
      return function(e) {
        realtimeBackupCoef = 1;
        _this.set('inSync', false);
        app.router.forceRefresh();
        return log.info("UPTODATE realtime", e);
      };
    })(this));
    this.liveReplication.once('complete', (function(_this) {
      return function(e) {
        log.info("REALTIME CANCELLED");
        _this.set('inSync', false);
        return _this.liveReplication = null;
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
        log.error("REALTIME BROKE, TRY AGAIN IN " + timeout + " " + (e.toString()));
        return _this.realtimeBackOff = setTimeout(_this.startRealtime, timeout);
      };
    })(this));
  };

  Replicator.prototype.stopRealtime = function() {
    var _ref;
    if ((_ref = this.liveReplication) != null) {
      _ref.cancel();
    }
    return clearTimeout(this.realtimeBackOff);
  };

  Replicator.prototype.syncCache = function(callback) {
    var options;
    this.set('backup_step', 'cache_sync');
    this.set('backup_step_done', null);
    options = {
      keys: this.cache.map(function(entry) {
        return entry.name.split('-')[0];
      }),
      include_docs: true
    };
    return this.db.query('ByBinaryId', options, (function(_this) {
      return function(err, results) {
        var processed, toUpdate;
        if (err) {
          return callback(err);
        }
        toUpdate = _this._filesNEntriesInCache(results.rows.map(function(row) {
          return row.doc;
        }));
        processed = 0;
        _this.set('backup_step', 'cache_sync');
        _this.set('backup_step_total', toUpdate.length);
        return async.eachSeries(toUpdate, function(fileNEntry, cb) {
          _this.set('backup_step_done', processed++);
          return _this.updateLocal(fileNEntry, cb);
        }, callback);
      };
    })(this));
  };

  return Replicator;

})(Backbone.Model);

});

require.register("replicator/replicator_backups", function(exports, require, module) {
var DeviceStatus, fs, log, request,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

DeviceStatus = require('../lib/device_status');

fs = require('./filesystem');

request = require('../lib/request');

log = require('/lib/persistent_log')({
  prefix: "replicator backup",
  date: true
});

module.exports = {
  backup: function(options, callback) {
    var e, err;
    if (callback == null) {
      callback = function() {};
    }
    if (this.get('inBackup')) {
      return callback(null);
    }
    options = options || {
      force: false
    };
    if (!this.config.has('checkpointed')) {
      err = new Error("Database not initialized before realtime");
      if (options.background) {
        callback(err);
      } else {
        log.warn(err);
        if (confirm(t('Database not initialized. Do it now ?'))) {
          app.router.navigate('first-sync', {
            trigger: true
          });
        }
      }
      return;
    }
    try {
      this.set('inBackup', true);
      this.set('backup_step', null);
      this.stopRealtime();
      return this._backup(options.force, (function(_this) {
        return function(err) {
          _this.set('backup_step', null);
          _this.set('backup_step_done', null);
          _this.set('inBackup', false);
          if (!options.background) {
            _this.startRealtime();
          }
          if (err) {
            return callback(err);
          }
          return _this.config.save({
            lastBackup: new Date().toString()
          }, function(err) {
            log.info("Backup done.");
            return callback(null);
          });
        };
      })(this));
    } catch (_error) {
      e = _error;
      return log.error("Error in backup: ", e);
    }
  },
  _backup: function(force, callback) {
    return DeviceStatus.checkReadyForSync((function(_this) {
      return function(err, ready, msg) {
        var errors;
        log.info("SYNC STATUS", err, ready, msg);
        if (err) {
          return callback(err);
        }
        if (!ready) {
          return callback(new Error(msg));
        }
        log.info("WE ARE READY FOR SYNC");
        errors = [];
        return async.series([
          function(cb) {
            return _this.syncPictures(force, function(err) {
              if (err) {
                log.error("in syncPictures: ", err);
                errors.push(err);
              }
              return cb();
            });
          }, function(cb) {
            return DeviceStatus.checkReadyForSync(function(err, ready, msg) {
              if (!(ready || err)) {
                err = new Error(msg);
              }
              if (err) {
                return cb(err);
              }
              return _this.syncCache(function(err) {
                if (err) {
                  log.error("in syncCache", err);
                  errors.push(err);
                }
                return cb();
              });
            });
          }, function(cb) {
            return DeviceStatus.checkReadyForSync(function(err, ready, msg) {
              if (!(ready || err)) {
                err = new Error(msg);
              }
              if (err) {
                resultsrn(cb(err));
              }
              return _this.syncContacts(function(err) {
                if (err) {
                  log.error("in syncContacts", err);
                  errors.push(err);
                }
                return cb();
              });
            });
          }
        ], function(err) {
          if (err) {
            return callback(err);
          }
          if (errors.length > 0) {
            return callback(errors[0]);
          } else {
            return callback();
          }
        });
      };
    })(this));
  },
  syncPictures: function(force, callback) {
    if (!this.config.get('syncImages')) {
      return callback(null);
    }
    log.info("sync pictures");
    this.set('backup_step', 'pictures_scan');
    this.set('backup_step_done', null);
    return async.series([
      this.ensureDeviceFolder.bind(this), ImagesBrowser.getImagesList, (function(_this) {
        return function(callback) {
          return _this.photosDB.query('PhotosByLocalId', {}, callback);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.db.query('FilesAndFolder', {
            startkey: ['/' + t('photos')],
            endkey: ['/' + t('photos'), {}]
          }, cb);
        };
      })(this)
    ], (function(_this) {
      return function(err, results) {
        var dbImages, dbPictures, device, errors, images, myDownloadFolder, toUpload, _ref;
        if (err) {
          return callback(err);
        }
        device = results[0], images = results[1], (_ref = results[2], dbImages = _ref.rows), dbPictures = results[3];
        dbImages = dbImages.map(function(row) {
          return row.key;
        });
        dbPictures = dbPictures.rows.map(function(row) {
          var _ref1;
          return (_ref1 = row.key[1]) != null ? _ref1.slice(2) : void 0;
        });
        myDownloadFolder = _this.downloads.toURL().replace('file://', '');
        toUpload = [];
        images = images.filter(function(path) {
          return (path != null) && path.indexOf('/DCIM/') !== -1;
        });
        images = images.filter(function(path) {
          return path.indexOf(':') === -1;
        });
        if (images.length === 0) {
          return callback(new Error('no images in DCIM'));
        }
        errors = [];
        return async.eachSeries(images, function(path, cb) {
          if (__indexOf.call(dbImages, path) >= 0) {
            return cb();
          } else {
            return fs.getFileFromPath(path, function(err, file) {
              var _ref1, _ref2;
              if (err) {
                err.message = err.message + ' - ' + path;
                log.info(err);
                errors.push(err);
                return cb();
              }
              if (_ref1 = (_ref2 = file.name) != null ? _ref2.toLowerCase() : void 0, __indexOf.call(dbPictures, _ref1) >= 0) {
                _this.createPhoto(path);
              } else {
                toUpload.push(path);
              }
              return DeviceStatus.checkReadyForSync(function(err, ready, msg) {
                if (err) {
                  return cb(err);
                }
                if (!ready) {
                  return cb(new Error(msg));
                }
                return setImmediate(cb);
              });
            });
          }
        }, function(err) {
          var processed;
          if (err) {
            return callback(err);
          }
          log.info("SYNC IMAGES : " + images.length + " " + toUpload.length);
          processed = 0;
          _this.set('backup_step', 'pictures_sync');
          _this.set('backup_step_total', toUpload.length);
          return async.eachSeries(toUpload, function(path, cb) {
            _this.set('backup_step_done', processed++);
            log.info("UPLOADING " + path);
            return _this.uploadPicture(path, device, function(err) {
              if (err) {
                log.error("ERROR " + path + " " + err);
                err.message = err.message + ' - ' + path;
                errors.push(err);
              }
              return DeviceStatus.checkReadyForSync(function(err, ready, msg) {
                if (err) {
                  return cb(err);
                }
                if (ready) {
                  return setImmediate(cb);
                } else {
                  return cb(new Error(msg));
                }
              });
            });
          }, function(err) {
            var messages;
            if (err) {
              return callback(err);
            }
            if (errors.length > 0) {
              messages = (errors.map(function(err) {
                return err.message;
              })).join('; ');
              return callback(new Error(messages));
            }
            return callback();
          });
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
      path: "/" + t('photos'),
      "class": this.fileClassFromMime(cordovaFile.type),
      mime: cordovaFile.type,
      lastModification: new Date(cordovaFile.lastModified).toISOString(),
      creationDate: new Date(cordovaFile.lastModified).toISOString(),
      size: cordovaFile.size,
      tags: ['from-' + this.config.get('deviceName')],
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
            return setTimeout((function() {
              return findDevice(id, callback);
            }), 200);
          }
        });
      };
    })(this);
    createNew = (function(_this) {
      return function() {
        var folder, options;
        log.info("creating 'photos' folder");
        folder = {
          docType: 'Folder',
          name: t('photos'),
          path: '',
          lastModification: new Date().toISOString(),
          creationDate: new Date().toISOString(),
          tags: []
        };
        options = {
          key: ['', "1_" + (folder.name.toLowerCase())]
        };
        return _this.config.remote.post(folder, function(err, res) {
          app.replicator.startRealtime();
          return findDevice(res.id, function() {
            if (err) {
              return callback(err);
            }
            return callback(null, folder);
          });
        });
      };
    })(this);
    return this.db.query('FilesAndFolder', {
      key: ['', "1_" + (t('photos').toLowerCase())]
    }, (function(_this) {
      return function(err, results) {
        var device, query;
        if (err) {
          return callback(err);
        }
        if (results.rows.length > 0) {
          device = results.rows[0];
          log.info("DEVICE FOLDER EXISTS");
          return callback(null, device);
        } else {
          query = '/_design/folder/_view/byfullpath/?' + ("key=\"/" + (t('photos')) + "\"");
          return request.get(_this.config.makeUrl(query), function(err, res, body) {
            var _ref;
            if (err) {
              return callback(err);
            }
            if ((body != null ? (_ref = body.rows) != null ? _ref.length : void 0 : void 0) === 0) {
              return createNew();
            } else {
              return callback(new Error('photo folder not replicated yet'));
            }
          });
        }
      };
    })(this));
  }
};

});

require.register("replicator/replicator_config", function(exports, require, module) {
var APP_VERSION, ReplicatorConfig, basic,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

basic = require('../lib/basic');

APP_VERSION = "0.1.11";

module.exports = ReplicatorConfig = (function(_super) {
  __extends(ReplicatorConfig, _super);

  function ReplicatorConfig(replicator) {
    this.replicator = replicator;
    ReplicatorConfig.__super__.constructor.call(this, null);
    this.remote = null;
  }

  ReplicatorConfig.prototype.defaults = function() {
    return {
      _id: '_local/appconfig',
      syncContacts: true,
      syncImages: true,
      syncOnWifi: true,
      cozyNotifications: false,
      cozyURL: '',
      deviceName: ''
    };
  };

  ReplicatorConfig.prototype.fetch = function(callback) {
    return this.replicator.db.get('_local/appconfig', (function(_this) {
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
    return this.replicator.db.get('_local/appconfig', (function(_this) {
      return function(err, config) {
        if (!err) {
          _this.set({
            _rev: config._rev
          });
        }
        return _this.replicator.db.put(_this.toJSON(), function(err, res) {
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
        });
      };
    })(this));
  };

  ReplicatorConfig.prototype.getScheme = function() {
    if (window.isBrowserDebugging) {
      return 'http';
    } else {
      return 'https';
    }
  };

  ReplicatorConfig.prototype.makeUrl = function(path) {
    return {
      json: true,
      auth: this.get('auth'),
      url: ("" + (this.getScheme()) + "://") + this.get('cozyURL') + '/cozy' + path
    };
  };

  ReplicatorConfig.prototype.makeFilterName = function() {
    return this.get('deviceId') + '/filter';
  };

  ReplicatorConfig.prototype.createRemotePouchInstance = function() {
    return new PouchDB({
      name: this.get('fullRemoteURL'),
      ajax: {
        timeout: 5 * 60 * 1000
      }
    });
  };

  ReplicatorConfig.prototype.appVersion = function() {
    return APP_VERSION;
  };

  return ReplicatorConfig;

})(Backbone.Model);

});

require.register("replicator/replicator_contacts", function(exports, require, module) {
var ACCOUNT_NAME, ACCOUNT_TYPE, Contact, log, request;

request = require('../lib/request');

Contact = require('../models/contact');

ACCOUNT_TYPE = 'io.cozy';

ACCOUNT_NAME = 'myCozy';

log = require('/lib/persistent_log')({
  prefix: "contacts replicator",
  date: true
});

module.exports = {
  syncContacts: function(callback) {
    if (!this.config.get('syncContacts')) {
      return callback(null);
    }
    this.set('backup_step', 'contacts_sync');
    this.set('backup_step_done', null);
    return async.series([
      (function(_this) {
        return function(cb) {
          if (_this.config.has('contactsPullCheckpointed')) {
            return cb();
          } else {
            return request.get(_this.config.makeUrl('/_changes?descending=true&limit=1'), function(err, res, body) {
              if (err) {
                return cb(err);
              }
              return _this.initContactsInPhone(body.last_seq, cb);
            });
          }
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.syncPhone2Pouch(cb);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.syncToCozy(cb);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.syncFromCozyToPouchToPhone(cb);
        };
      })(this)
    ], function(err) {
      log.info("Sync contacts done");
      return callback(err);
    });
  },
  createAccount: (function(_this) {
    return function(callback) {
      return navigator.contacts.createAccount(ACCOUNT_TYPE, ACCOUNT_NAME, function() {
        return callback(null);
      }, callback);
    };
  })(this),
  _updateInPouch: function(phoneContact, callback) {
    return async.parallel({
      fromPouch: (function(_this) {
        return function(cb) {
          return _this.db.get(phoneContact.sourceId, {
            attachments: true
          }, cb);
        };
      })(this),
      fromPhone: function(cb) {
        return Contact.cordova2Cozy(phoneContact, cb);
      }
    }, (function(_this) {
      return function(err, res) {
        var contact, oldPicture, picture, _ref, _ref1, _ref2;
        if (err) {
          return callback(err);
        }
        contact = _.extend(res.fromPouch, res.fromPhone);
        if (((_ref = contact._attachments) != null ? _ref.picture : void 0) != null) {
          picture = contact._attachments.picture;
          if (((_ref1 = res.fromPouch._attachments) != null ? _ref1.picture : void 0) != null) {
            oldPicture = ((_ref2 = res.fromPouch._attachments) != null ? _ref2.picture : void 0) != null;
            if (oldPicture.data === picture.data) {
              picture.revpos = oldPicture.revpos;
            } else {
              picture.revpos = 1 + parseInt(contact._rev.split('-')[0]);
            }
          }
        }
        return _this.db.put(contact, contact._id, contact._rev, function(err, idNrev) {
          if (err) {
            if (err.status === 409) {
              log.error("UpdateInPouch, immediate conflict with " + contact._id + ".", err);
              return callback(null);
            } else if (err.message === "Some query argument is invalid") {
              log.error("While retrying update contact in pouch", err);
              return callback(null);
            } else {
              return callback(err);
            }
          }
          return _this._undirty(phoneContact, idNrev, callback);
        });
      };
    })(this));
  },
  _createInPouch: function(phoneContact, callback) {
    return Contact.cordova2Cozy(phoneContact, (function(_this) {
      return function(err, fromPhone) {
        var contact, _ref;
        contact = _.extend({
          docType: 'contact',
          tags: []
        }, fromPhone);
        if (((_ref = contact._attachments) != null ? _ref.picture : void 0) != null) {
          contact._attachments.picture.revpos = 1;
        }
        return _this.db.post(contact, function(err, idNrev) {
          if (err) {
            if (err.message === "Some query argument is invalid") {
              log.error("While retrying create contact in pouch", err);
              return callback(null);
            } else {
              return callback(err);
            }
          }
          return _this._undirty(phoneContact, idNrev, callback);
        });
      };
    })(this));
  },
  _undirty: function(dirtyContact, idNrev, callback) {
    dirtyContact.dirty = false;
    dirtyContact.sourceId = idNrev.id;
    dirtyContact.sync2 = idNrev.rev;
    return dirtyContact.save(function() {
      return callback(null);
    }, callback, {
      accountType: ACCOUNT_TYPE,
      accountName: ACCOUNT_NAME,
      callerIsSyncAdapter: true
    });
  },
  _deleteInPouch: function(phoneContact, callback) {
    var toDelete;
    toDelete = {
      docType: 'contact',
      _id: phoneContact.sourceId,
      _rev: phoneContact.sync2,
      _deleted: true
    };
    return this.db.put(toDelete, toDelete._id, toDelete._rev, (function(_this) {
      return function(err, res) {
        return phoneContact.remove((function() {
          return callback();
        }), callback, {
          callerIsSyncAdapter: true
        });
      };
    })(this));
  },
  syncPhone2Pouch: function(callback) {
    log.info("enter syncPhone2Pouch");
    return navigator.contacts.find([navigator.contacts.fieldType.dirty], (function(_this) {
      return function(contacts) {
        var processed;
        processed = 0;
        _this.set('backup_step', 'contacts_sync_to_pouch');
        _this.set('backup_step_total', contacts.length);
        log.info("syncPhone2Pouch " + contacts.length + " contacts.");
        return async.eachSeries(contacts, function(contact, cb) {
          _this.set('backup_step_done', processed++);
          return setImmediate(function() {
            if (contact.deleted) {
              return _this._deleteInPouch(contact, cb);
            } else if (contact.sourceId) {
              return _this._updateInPouch(contact, cb);
            } else {
              return _this._createInPouch(contact, cb);
            }
          });
        }, callback);
      };
    })(this), callback, new ContactFindOptions("1", true, [], ACCOUNT_TYPE, ACCOUNT_NAME));
  },
  syncToCozy: function(callback) {
    var replication;
    log.info("enter sync2Cozy");
    this.set('backup_step_done', null);
    this.set('backup_step', 'contacts_sync_to_cozy');
    replication = this.db.replicate.to(this.config.remote, {
      batch_size: 20,
      batches_limit: 5,
      filter: function(doc) {
        var _ref;
        return (doc != null) && ((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'contact';
      },
      live: false,
      since: this.config.get('contactsPushCheckpointed')
    });
    replication.on('error', callback);
    return replication.on('complete', (function(_this) {
      return function(result) {
        return _this.config.save({
          contactsPushCheckpointed: result.last_seq
        }, callback);
      };
    })(this));
  },
  _saveContactInPhone: function(cozyContact, phoneContact, callback) {
    var options, toSaveInPhone;
    toSaveInPhone = Contact.cozy2Cordova(cozyContact);
    if (phoneContact) {
      toSaveInPhone.id = phoneContact.id;
      toSaveInPhone.rawId = phoneContact.rawId;
    }
    options = {
      accountType: ACCOUNT_TYPE,
      accountName: ACCOUNT_NAME,
      callerIsSyncAdapter: true,
      resetFields: true
    };
    return toSaveInPhone.save(function(contact) {
      return callback(null, contact);
    }, callback, options);
  },
  _applyChangeToPhone: function(docs, callback) {
    var getFromPhoneBySourceId;
    getFromPhoneBySourceId = function(sourceId, cb) {
      return navigator.contacts.find([navigator.contacts.fieldType.sourceId], function(contacts) {
        return cb(null, contacts[0]);
      }, cb, new ContactFindOptions(sourceId, false, [], ACCOUNT_TYPE, ACCOUNT_NAME));
    };
    return async.eachSeries(docs, (function(_this) {
      return function(doc, cb) {
        _this.set('backup_step_done', _this.get('backup_step_done') + 1);
        return getFromPhoneBySourceId(doc._id, function(err, contact) {
          if (err) {
            return cb(err);
          }
          if (doc._deleted) {
            if (contact != null) {
              return contact.remove((function() {
                return cb();
              }), cb, {
                callerIsSyncAdapter: true
              });
            }
          } else {
            return _this._saveContactInPhone(doc, contact, cb);
          }
        });
      };
    })(this), function(err) {
      return callback(err);
    });
  },
  syncFromCozyToPouchToPhone: function(callback) {
    var applyToPhoneQueue, replication, replicationDone, total;
    log.info("enter syncCozy2Phone");
    replicationDone = false;
    total = 0;
    this.set('backup_step', 'contacts_sync_to_phone');
    this.set('backup_step_done', 0);
    applyToPhoneQueue = async.queue(this._applyChangeToPhone.bind(this));
    applyToPhoneQueue.drain = function() {
      if (replicationDone) {
        return callback();
      }
    };
    replication = this.db.replicate.from(this.config.remote, {
      batch_size: 20,
      batches_limit: 1,
      filter: function(doc) {
        var _ref;
        return (doc != null) && ((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'contact';
      },
      live: false,
      since: this.config.get('contactsPullCheckpointed')
    });
    replication.on('change', (function(_this) {
      return function(changes) {
        var _ref;
        applyToPhoneQueue.push($.extend(true, {}, changes.docs));
        total += (_ref = changes.docs) != null ? _ref.length : void 0;
        _this.set('backup_step_total', total);
        return log.info("sync2Phone " + total + " contacts.");
      };
    })(this));
    replication.on('error', callback);
    return replication.on('complete', (function(_this) {
      return function(result) {
        return _this.config.save({
          contactsPullCheckpointed: result.last_seq
        }, function() {
          replicationDone = true;
          if (applyToPhoneQueue.idle()) {
            applyToPhoneQueue.drain = null;
            return callback();
          }
        });
      };
    })(this));
  },
  initContactsInPhone: function(lastSeq, callback) {
    if (!this.config.get('syncContacts')) {
      return callback();
    }
    return this.createAccount((function(_this) {
      return function(err) {
        return request.get(_this.config.makeUrl("/_design/contact/_view/all/"), function(err, res, body) {
          var _ref;
          if (err) {
            return callback(err);
          }
          if (!((_ref = body.rows) != null ? _ref.length : void 0)) {
            return callback(null);
          }
          return async.mapSeries(body.rows, function(row, cb) {
            var doc, _ref1;
            doc = row.value;
            if (((_ref1 = doc._attachments) != null ? _ref1.picture : void 0) != null) {
              return request.get(_this.config.makeUrl("/" + doc._id + "?attachments=true"), function(err, res, body) {
                if (err) {
                  return cb(err);
                }
                return cb(null, body);
              });
            } else {
              return cb(null, doc);
            }
          }, function(err, docs) {
            if (err) {
              return callback(err);
            }
            return async.mapSeries(docs, function(doc, cb) {
              return _this.db.put(doc, {
                'new_edits': false
              }, cb);
            }, function(err, contacts) {
              if (err) {
                return callback(err);
              }
              _this.set('backup_step', null);
              return _this._applyChangeToPhone(docs, function(err) {
                _this.set('backup_step_done', null);
                return _this.config.save({
                  contactsPullCheckpointed: lastSeq
                }, function(err) {
                  return _this.deleteObsoletePhoneContacts(callback);
                });
              });
            });
          });
        });
      };
    })(this));
  },
  deleteObsoletePhoneContacts: function(callback) {
    log.info("enter deleteObsoletePhoneContacts");
    return async.parallel({
      phone: function(cb) {
        return navigator.contacts.find([navigator.contacts.fieldType.id], function(contacts) {
          return cb(null, contacts);
        }, cb, new ContactFindOptions("", true, [], ACCOUNT_TYPE, ACCOUNT_NAME));
      },
      pouch: (function(_this) {
        return function(cb) {
          return _this.db.query("Contacts", {}, cb);
        };
      })(this)
    }, (function(_this) {
      return function(err, contacts) {
        var idsInPouch, row, _i, _len, _ref;
        if (err) {
          return callback(err);
        }
        idsInPouch = {};
        _ref = contacts.pouch.rows;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          row = _ref[_i];
          idsInPouch[row.id] = true;
        }
        return async.eachSeries(contacts.phone, function(contact, cb) {
          if (!(contact.sourceId in idsInPouch)) {
            log.info("Delete contact: " + contact.sourceId);
            return contact.remove((function() {
              return cb();
            }), cb, {
              callerIsSyncAdapter: true
            });
          }
          return cb();
        }, callback);
      };
    })(this));
  }
};

});

require.register("replicator/replicator_mapreduce", function(exports, require, module) {
var ByBinaryIdDesignDoc, ContactsDesignDoc, FilesAndFolderDesignDoc, LocalPathDesignDoc, NotificationsTemporaryDesignDoc, PathToBinaryDesignDoc, PhotosByLocalIdDesignDoc, PicturesDesignDoc, createOrUpdateDesign, log;

log = require('/lib/persistent_log')({
  prefix: "replicator mapreduce",
  date: true
});

createOrUpdateDesign = function(db, design, callback) {
  return db.get(design._id, (function(_this) {
    return function(err, existing) {
      if ((existing != null ? existing.version : void 0) === design.version) {
        return callback(null);
      } else {
        log.info("REDEFINING DESIGN " + design._id + " FROM " + existing);
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
        if (doc.name != null) {
          if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file') {
            emit([doc.path, '2_' + doc.name.toLowerCase()]);
          }
          if (((_ref1 = doc.docType) != null ? _ref1.toLowerCase() : void 0) === 'folder') {
            return emit([doc.path, '1_' + doc.name.toLowerCase()]);
          }
        }
      })
    }
  }
};

ByBinaryIdDesignDoc = {
  _id: '_design/ByBinaryId',
  version: 1,
  views: {
    'ByBinaryId': {
      map: Object.toString.apply(function(doc) {
        var _ref, _ref1, _ref2;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file') {
          return emit((_ref1 = doc.binary) != null ? (_ref2 = _ref1.file) != null ? _ref2.id : void 0 : void 0);
        }
      })
    }
  }
};

PicturesDesignDoc = {
  _id: '_design/Pictures',
  version: 1,
  views: {
    'Pictures': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (doc.lastModification != null) {
          if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'file') {
            return emit([doc.path, doc.lastModification]);
          }
        }
      })
    }
  }
};

NotificationsTemporaryDesignDoc = {
  _id: '_design/NotificationsTemporary',
  version: 1,
  views: {
    'NotificationsTemporary': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'notification' && doc.type === 'temporary') {
          return emit(doc._id);
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

ContactsDesignDoc = {
  _id: '_design/Contacts',
  version: 1,
  views: {
    'Contacts': {
      map: Object.toString.apply(function(doc) {
        var _ref;
        if (((_ref = doc.docType) != null ? _ref.toLowerCase() : void 0) === 'contact') {
          return emit(doc._id);
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

module.exports = function(db, photosDB, callback) {
  return async.series([
    function(cb) {
      return createOrUpdateDesign(db, NotificationsTemporaryDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, FilesAndFolderDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, ByBinaryIdDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, PicturesDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, LocalPathDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, PathToBinaryDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(db, ContactsDesignDoc, cb);
    }, function(cb) {
      return createOrUpdateDesign(photosDB, PhotosByLocalIdDesignDoc, cb);
    }
  ], callback);
};

});

require.register("replicator/replicator_migration", function(exports, require, module) {
var DBNAME, DBPHOTOS, log;

log = require('/lib/persistent_log')({
  prefix: "replicator_migration_sqlite",
  date: true
});

DBNAME = "cozy-files.db";

DBPHOTOS = "cozy-photos.db";

module.exports = {
  sqliteDB: null,
  sqliteDBPhotos: null,
  migrateDBs: function(callback) {
    return this.db.get('_local/appconfig', (function(_this) {
      return function(err, config) {
        if (err && (err.status !== 404)) {
          return callback(err);
        }
        if (config != null) {
          return callback(null, 'db already configured');
        }
        _this.initSQLiteDBs();
        return _this.sqliteDB.get('localconfig', function(err, config) {
          if (err && (err.status !== 404)) {
            return callback(err);
          }
          if (config == null) {
            return callback(null, 'nothing to migrate');
          }
          log.info('Migrate sqlite db to idb');
          _this.displayMessage();
          return _this.replicateDBs(function(err) {
            if (err) {
              return callback(err);
            }
            return _this.destroySQLiteDBs(callback);
          });
        });
      };
    })(this));
  },
  initSQLiteDBs: function() {
    this.sqliteDBPhotos = new PouchDB(DBPHOTOS, {
      adapter: 'websql'
    });
    return this.sqliteDB = new PouchDB(DBNAME, {
      adapter: 'websql'
    });
  },
  replicateDBs: function(callback) {
    var replicateDB;
    replicateDB = function(origin, destination, cb) {
      var replication;
      replication = origin.replicate.to(destination);
      replication.on('error', cb);
      return replication.on('complete', function(report) {
        return cb(null, report);
      });
    };
    return async.series([
      (function(_this) {
        return function(cb) {
          return replicateDB(_this.sqliteDBPhotos, _this.photosDB, cb);
        };
      })(this), (function(_this) {
        return function(cb) {
          return replicateDB(_this.sqliteDB, _this.db, cb);
        };
      })(this), (function(_this) {
        return function(cb) {
          return _this.moveConfig(cb);
        };
      })(this)
    ], callback);
  },
  moveConfig: function(callback) {
    return this.db.get('localconfig', (function(_this) {
      return function(err, config) {
        var id, rev;
        if (err) {
          return callback(err);
        }
        id = config._id;
        rev = config._rev;
        config._id = '_local/appconfig';
        delete config._rev;
        return _this.db.put(config, function(err, newConfig) {
          if (err) {
            return callback(err);
          }
          return _this.db.remove(id, rev, callback);
        });
      };
    })(this));
  },
  destroySQLiteDBs: function(callback) {
    return async.eachSeries([this.sqliteDBPhotos, this.sqliteDB], (function(_this) {
      return function(db, cb) {
        return db.destroy(cb);
      };
    })(this), callback);
  },
  displayMessage: function() {
    var splashMessage;
    splashMessage = $('<div class="splash-message"></div>');
    splashMessage.text(t('please wait database migration'));
    return $('body').append(splashMessage);
  }
};

});

require.register("router", function(exports, require, module) {
var ConfigView, DeviceNamePickerView, FirstSyncView, FolderCollection, FolderView, LoginView, Router, app, log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

app = require('application');

FolderView = require('./views/folder');

LoginView = require('./views/login');

DeviceNamePickerView = require('./views/device_name_picker');

FirstSyncView = require('./views/first_sync');

ConfigView = require('./views/config');

FolderCollection = require('./collections/files');

log = require('/lib/persistent_log')({
  prefix: "replicator",
  date: true
});

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
    var collection;
    $('#btn-menu').show();
    $('#btn-back').hide();
    app.layout.setBreadcrumbs(path);
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
    $('#btn-menu').show();
    $('#btn-back').hide();
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
          log.error(err.stack);
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
    $('#btn-menu, #btn-back').hide();
    return this.display(new DeviceNamePickerView());
  };

  Router.prototype.firstSync = function() {
    app.layout.setTitle(t('setup end'));
    $('#btn-menu, #btn-back').hide();
    return this.display(new FirstSyncView());
  };

  Router.prototype.config = function() {
    var titleKey;
    console.log("router.config");
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

require.register("service/service", function(exports, require, module) {
var DeviceStatus, Notifications, Replicator, Service, log;

require('/lib/utils');

Replicator = require('../replicator/main');

Notifications = require('../views/notifications');

DeviceStatus = require('../lib/device_status');

log = require('/lib/persistent_log')({
  prefix: "application",
  date: true,
  processusTag: "Service"
});

module.exports = Service = {
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
        var e, locales;
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
        _this.replicator = new Replicator();
        return _this.replicator.init(function(err, config) {
          var delayedQuit;
          if (err) {
            log.error(err);
            return window.service.workDone();
          }
          if (config.remote) {
            if (!_this.replicator.config.has('checkpointed')) {
              log.error(new Error("Database not initialized"));
              return window.service.workDone();
            }
            DeviceStatus.initialize();
            if (config.get('cozyNotifications')) {
              _this.notificationManager = new Notifications();
            }
            delayedQuit = function(err) {
              if (err) {
                log.error(err);
              }
              return setTimeout(function() {
                return window.service.workDone();
              }, 5 * 1000);
            };
            return app.replicator.backup({
              background: true
            }, function(err) {
              if (err) {
                log.error("Error launching backup: ", err);
                return delayedQuit();
              } else {
                return app.replicator.sync({
                  background: true
                }, delayedQuit);
              }
            });
          } else {
            return window.service.workDone();
          }
        });
      };
    })(this));
  }
};

document.addEventListener('deviceready', function() {
  var error;
  try {
    return Service.initialize();
  } catch (_error) {
    error = _error;
    return log.error('EXCEPTION SERVICE INITIALIZATION : ', err);
  } finally {
    setTimeout(function() {
      return window.service.workDone();
    }, 10 * 60 * 1000);
  }
});

});

require.register("service/service_manager", function(exports, require, module) {
var ServiceManager, log, repeatingPeriod,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

log = require('/lib/persistent_log')({
  prefix: "ServiceManager",
  date: true
});

repeatingPeriod = 15 * 60 * 1000;

module.exports = ServiceManager = (function(_super) {
  __extends(ServiceManager, _super);

  function ServiceManager() {
    return ServiceManager.__super__.constructor.apply(this, arguments);
  }

  ServiceManager.prototype.defaults = function() {
    return {
      daemonActivated: false
    };
  };

  ServiceManager.prototype.initialize = function() {
    var config;
    config = app.replicator.config;
    this.listenNewPictures(config, config.get('syncImages'));
    this.toggle(config, true);
    this.listenTo(app.replicator.config, "change:syncImages", this.listenNewPictures);
    return this.checkActivated();
  };

  ServiceManager.prototype.isActivated = function() {
    return this.get('daemonActivated');
  };

  ServiceManager.prototype.checkActivated = function() {
    return window.JSBackgroundService.isRepeating((function(_this) {
      return function(err, isRepeating) {
        if (err) {
          log.error(err);
          isRepeating = false;
        }
        return _this.set('daemonActivated', isRepeating);
      };
    })(this));
  };

  ServiceManager.prototype.activate = function(repeatingPeriod) {
    return window.JSBackgroundService.setRepeating(repeatingPeriod, (function(_this) {
      return function(err) {
        if (err) {
          return console.log(err);
        }
        return _this.checkActivated();
      };
    })(this));
  };

  ServiceManager.prototype.deactivate = function() {
    return window.JSBackgroundService.cancelRepeating((function(_this) {
      return function(err) {
        if (err) {
          return console.log(err);
        }
        return _this.checkActivated();
      };
    })(this));
  };

  ServiceManager.prototype.toggle = function(config, activate) {
    if (activate) {
      return this.activate();
    } else {
      return this.deactivate();
    }
  };

  ServiceManager.prototype.listenNewPictures = function(config, listen) {
    return window.JSBackgroundService.listenNewPictures(listen, function(err) {
      if (err) {
        return console.log(err);
      }
    });
  };

  return ServiceManager;

})(Backbone.Model);

});

require.register("templates/breadcrumbs", function(exports, require, module) {
module.exports = function anonymous(locals, attrs, escape, rethrow, merge) {
attrs = attrs || jade.attrs; escape = escape || jade.escape; rethrow = rethrow || jade.rethrow; merge = merge || jade.merge;
var buf = [];
with (locals || {}) {
var interp;
buf.push('<a href="#folder/" class="home"><div class="span">');
var __val__ = t('files')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div style="display: none;" class="arrow"><div class="blue-arrow"></div><div class="white-arrow"></div></div></a><div id="crumbs">');
if ( hasFolder)
{
buf.push('<ul><li><a');
buf.push(attrs({ 'href':("#folder" + (folder.path) + "") }, {"href":true}));
buf.push('></a>' + escape((interp = folder.name) == null ? '' : interp) + '</li></ul>');
}
buf.push('</div>');
}
return buf.join("");
};
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
buf.push('</div><div class="item item-checkbox">');
var __val__ = t('contacts sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('contactSyncCheck'), 'type':("checkbox"), 'checked':(syncContacts) }, {"type":true,"checked":true}));
buf.push('/></label></div><div class="item item-checkbox">');
var __val__ = t('images sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('imageSyncCheck'), 'type':("checkbox"), 'checked':(syncImages) }, {"type":true,"checked":true}));
buf.push('/></label></div><div class="item item-checkbox">');
var __val__ = t('wifi sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('wifiSyncCheck'), 'type':("checkbox"), 'checked':(syncOnWifi) }, {"type":true,"checked":true}));
buf.push('/></label></div><div class="item item-checkbox">');
var __val__ = t('cozy notifications sync label')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('<label class="checkbox"><input');
buf.push(attrs({ 'id':('cozyNotificationsCheck'), 'type':("checkbox"), 'checked':(cozyNotifications) }, {"type":true,"checked":true}));
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
buf.push('<div id="doBackup" class="item item-icon"><div class="icon-backup"></div><span class="text">');
var __val__ = t('last backup')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('&nbsp;' + escape((interp = lastBackup) == null ? '' : interp) + '.</span></div><div class="item item-divider">');
var __val__ = t('about')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('synchronized with') + " " + cozyURL
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('device name') + ' : ' + deviceName
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item">');
var __val__ = t('app name') + ' v' + appVersion
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item item-divider">');
var __val__ = t('reset title')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item"><p>');
var __val__ = t('synchro warning')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</p><button id="synchrobtn" class="button button-grey button-full-width">');
var __val__ = t('retry synchro')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div><div class="item"><p>');
var __val__ = t('reset warning')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</p><button id="redbtn" class="button button-energized button-full-width">');
var __val__ = t('reset action')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div><div class="item item-divider">');
var __val__ = t('support')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div><div class="item"><p>');
var __val__ = t('send log info')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</p><button id="sendlogbtn" class="button button-grey button-full-width">');
var __val__ = t('send log')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div>');
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
buf.push('<div id="deviceNamePicker" class="list"><div class="card no-shadow more-spacing flat"><div class="item item-text-wrap">');
var __val__ = t('device name explanation')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div></div><div class="card no-shadow more-spacing"><label><input');
buf.push(attrs({ 'id':('input-device'), 'type':("text"), 'value':("" + (t('device name placeholder')) + "") }, {"type":true,"value":true}));
buf.push('/></label><div class="button-bar"><button id="btn-back" class="button button-dark button-clear">');
var __val__ = t('back')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button><button id="btn-save" class="button button-balanced">');
var __val__ = t('next')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div></div></div>');
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
buf.push('<div class="list"><div id="finishSync" class="card no-shadow more-spacing flat"><div class="progress item item-text-wrap">');
var __val__ = messageText
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</div></div><div class="card no-shadow more-spacing"><button id="btn-end" class="button button-block button-balanced">');
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
buf.push('<i class="icon icon-type type-folder"></i>');
}
else
{
buf.push('<i');
buf.push(attrs({ "class": ("icon icon-type " + (this.mimeClasses[model.mime]) + "") }, {"class":true}));
buf.push('></i>');
}
buf.push('<span>');
var __val__ = model.name
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</span>');
if ( isFolder)
{
buf.push('<i class="cache-indicator icon icon-download"></i>');
}
else if ( model.incache && model.version)
{
buf.push('<i class="cache-indicator icon icon-phone"></i>');
}
else if ( model.incache)
{
buf.push('<i class="cache-indicator-version icon icon-phone"></i>');
}
else
{
buf.push('<i class="cache-indicator icon icon-download"></i>');
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
buf.push('<div id="container" class="pane"><div id="bar-header" class="bar bar-header"><a id="btn-menu" class="btn-menu"></a><div id="icon-logo" class="icon-logo"></div><h1 id="title" class="title">Loading</h1><div id="breadcrumbs"></div><a id="headerSpinner" class="spinner"><img src="img/spinner.svg"/></a></div><div class="bar bar-subheader bar-calm"><h2 id="backupIndicator" class="title"></h2></div><div id="viewsPlaceholder" class="scroll-content has-header"><div class="scroll"></div></div></div>');
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
buf.push('<div class="list"><div class="card no-shadow more-spacing flat"><div class="item item-text-wrap"><h2 class="welcome"></h2><p class="welcome-message"></p></div></div><div class="card no-shadow more-spacing"><label><input');
buf.push(attrs({ 'id':('input-url'), 'type':("url"), 'placeholder':("" + (t('url placeholder')) + ""), 'value':("" + (defaultValue.cozyURL) + "") }, {"type":true,"placeholder":true,"value":true}));
buf.push('/></label><label><input');
buf.push(attrs({ 'id':('input-pass'), 'type':("password"), 'placeholder':("" + (t('password placeholder')) + ""), 'value':("" + (defaultValue.password) + "") }, {"type":true,"placeholder":true,"value":true}));
buf.push('/></label><button id="btn-save" class="button button-block button-balanced">');
var __val__ = t('next')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</button></div><div class="card no-shadow more-spacing"><div class="item item-text-wrap"><p class="no-account"></p></div></div></div>');
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
buf.push('<div class="content"><div class="item item-input-inset"><label class="item-input-wrapper"><input');
buf.push(attrs({ 'id':('search-input'), 'type':("text"), 'placeholder':(t("search")) }, {"type":true,"placeholder":true}));
buf.push('/></label><a id="btn-search" class="btn-search"></a></div><a href="#folder/" class="item icon-folder">');
var __val__ = t('files')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a><a href="#config" class="item icon-cog">');
var __val__ = t('config')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a><a id="syncButton" class="item icon-sync">');
var __val__ = t('sync')
buf.push(escape(null == __val__ ? "" : __val__));
buf.push('</a></div>');
}
return buf.join("");
};
});

require.register("views/breadcrumbs", function(exports, require, module) {
var BaseView, BreadcrumbsView,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

module.exports = BreadcrumbsView = (function(_super) {
  __extends(BreadcrumbsView, _super);

  function BreadcrumbsView() {
    return BreadcrumbsView.__super__.constructor.apply(this, arguments);
  }

  BreadcrumbsView.prototype.id = 'breadcrumbs';

  BreadcrumbsView.prototype.template = require('../templates/breadcrumbs');

  BreadcrumbsView.prototype.initialize = function(options) {
    if (options.path != null) {
      return this.folder = {
        name: options.path.split('/').slice(-1)[0],
        path: options.path
      };
    }
  };

  BreadcrumbsView.prototype.getRenderData = function() {
    return {
      hasFolder: this.folder != null,
      folder: this.folder
    };
  };

  BreadcrumbsView.prototype.afterRender = function() {
    if (this.folder) {
      this.$('#crumbs').show();
      this.$('.home .arrow').show();
    } else {
      this.$('#crumbs').hide();
      this.$('.home .arrow').hide();
    }
    return this;
  };

  return BreadcrumbsView;

})(BaseView);

});

require.register("views/config", function(exports, require, module) {
var BaseView, ConfigView, log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

log = require('/lib/persistent_log')({
  prefix: "config view",
  date: true
});

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
      'tap #sendlogbtn': 'sendlogBtn',
      'tap #contactSyncCheck': 'saveChanges',
      'tap #imageSyncCheck': 'saveChanges',
      'tap #wifiSyncCheck': 'saveChanges',
      'tap #cozyNotificationsCheck': 'saveChanges'
    };
  };

  ConfigView.prototype.getRenderData = function() {
    var config;
    config = app.replicator.config.toJSON();
    return _.extend({}, config, {
      lastSync: this.formatDate(config != null ? config.lastSync : void 0),
      lastBackup: this.formatDate(config != null ? config.lastBackup : void 0),
      firstRun: app.isFirstRun,
      locale: app.locale,
      appVersion: app.replicator.config.appVersion()
    });
  };

  ConfigView.prototype.formatDate = function(date) {
    if (!date) {
      return t('never');
    } else {
      if (!(date instanceof Date)) {
        date = new Date(date);
      }
      return date.toISOString().slice(0, 19).replace('T', ' ');
    }
  };

  ConfigView.prototype.configDone = function() {
    return app.router.navigate('first-sync', {
      trigger: true
    });
  };

  ConfigView.prototype.redBtn = function() {
    if (confirm(t('confirm message'))) {
      app.replicator.set('inSync', true);
      app.replicator.set('backup_step', 'destroying database');
      return app.replicator.destroyDB((function(_this) {
        return function(err) {
          if (err) {
            log.error(err);
            return alert(err.message);
          }
          $('#redbtn').text(t('done'));
          require('lib/device_status').shutdown();
          return window.location.reload(true);
        };
      })(this));
    }
  };

  ConfigView.prototype.synchroBtn = function() {
    if (confirm(t('confirm message'))) {
      return app.router.navigate('first-sync', {
        trigger: true
      });
    }
  };

  ConfigView.prototype.sendlogBtn = function() {
    var body, query, subject;
    subject = "Log from cozy-mobile v" + app.replicator.config.appVersion();
    body = "" + (t('send log please describe problem')) + "\n\n\n########################\n# " + (t('send log trace begin')) + "\n##\n\n" + (log.getTraces().join('\n')) + "\n\n##\n# " + (t('send log trace end')) + "\n########################\n\n\n" + (t('send log please describe problem')) + "\n";
    query = "subject=" + (encodeURI(subject)) + "&body=" + (encodeURI(body));
    return window.open("mailto:guillaume@cozycloud.cc?" + query, "_system");
  };

  ConfigView.prototype.saveChanges = function() {
    var checkboxes;
    log.info("Save changes");
    checkboxes = this.$('#contactSyncCheck, #imageSyncCheck,' + '#wifiSyncCheck, #cozyNotificationsCheck' + '#configDone');
    checkboxes.prop('disabled', true);
    return app.replicator.config.save({
      syncContacts: this.$('#contactSyncCheck').is(':checked'),
      syncImages: this.$('#imageSyncCheck').is(':checked'),
      syncOnWifi: this.$('#wifiSyncCheck').is(':checked'),
      cozyNotifications: this.$('#cozyNotificationsCheck').is(':checked')
    }, function() {
      return checkboxes.prop('disabled', false);
    });
  };

  return ConfigView;

})(BaseView);

});

require.register("views/device_name_picker", function(exports, require, module) {
var BaseView, DeviceNamePickerView, log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

log = require('/lib/persistent_log')({
  prefix: "DeviceNamePickerView",
  date: true
});

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
      'blur #input-device': 'onCompleteDefaultValue',
      'focus #input-device': 'onRemoveDefaultValue',
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
        if (err != null) {
          log.error(err);
          return _this.displayError(t(err.message));
        } else {
          delete app.loginConfig;
          app.isFirstRun = true;
          return app.router.navigate('config', {
            trigger: true
          });
        }
      };
    })(this));
  };

  DeviceNamePickerView.prototype.onCompleteDefaultValue = function() {
    var device;
    device = this.$('#input-device').val();
    if (device === '') {
      return this.$('#input-device').val(t('device name placeholder'));
    }
  };

  DeviceNamePickerView.prototype.onRemoveDefaultValue = function() {
    var device;
    device = this.$('#input-device').val();
    if (device === t('device name placeholder')) {
      return this.$('#input-device').val('');
    }
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
    this.error = $('<div>').addClass('error-msg');
    this.error.text(text);
    return this.$(field || 'label').after(this.error);
  };

  return DeviceNamePickerView;

})(BaseView);

});

require.register("views/first_sync", function(exports, require, module) {
var BaseView, FirstSyncView, LAST_STEP, log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

LAST_STEP = 5;

log = require('/lib/persistent_log')({
  prefix: "FirstSyncView",
  date: true
});

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
    var buttonText, messageText, step;
    step = app.replicator.get('initialReplicationStep');
    log.info("onChange : " + step);
    if (step === LAST_STEP) {
      messageText = t('ready message');
      buttonText = t('end');
    } else {
      messageText = t("message step " + step);
      buttonText = t('waiting...');
    }
    return {
      messageText: messageText,
      buttonText: buttonText
    };
  };

  FirstSyncView.prototype.initialize = function() {
    this.listenTo(app.replicator, 'change:initialReplicationStep', this.onChange);
    log.info('starting first replication');
    return app.replicator.initialReplication(function(err) {
      if (err) {
        log.error(err);
        alert(t(err.message));
        return setImmediate(function() {
          return app.router.navigate('config', {
            trigger: true
          });
        });
      }
    });
  };

  FirstSyncView.prototype.onChange = function(replicator) {
    var step;
    step = replicator.get('initialReplicationStep');
    this.$('#finishSync .progress').text(t("message step " + step));
    if (step === LAST_STEP) {
      return this.render();
    }
  };

  FirstSyncView.prototype.end = function() {
    var step;
    step = parseInt(app.replicator.get('initialReplicationStep'));
    log.info("end " + step);
    if (step !== LAST_STEP) {
      return;
    }
    app.isFirstRun = false;
    return app.regularStart();
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
    this.checkScroll = __bind(this.checkScroll, this);
    this.displaySlider = __bind(this.displaySlider, this);
    this.remove = __bind(this.remove, this);
    this.appendView = __bind(this.appendView, this);
    this.onChange = __bind(this.onChange, this);
    return FolderView.__super__.constructor.apply(this, arguments);
  }

  FolderView.prototype.className = 'list';

  FolderView.prototype.itemview = require('./folder_line');

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
      _handleDrag: (function(_this) {
        return function(e) {
          var gesture;
          gesture = e.gesture;
          if (gesture.direction === 'up') {
            gesture.deltaX = 0;
            gesture.angle = -90;
            gesture.distance = -1 * gesture.deltaY;
            gesture.velocityX = 0;
          } else if (gesture.direction === 'down') {
            gesture.deltaX = 0;
            gesture.angle = 90;
            gesture.distance = gesture.deltaY;
            gesture.velocityX = 0;
          } else if (gesture.direction === 'left') {
            gesture.deltaY = 0;
            gesture.angle = 180;
            gesture.distance = gesture.deltaX;
            gesture.velocityY = 0;
          } else if (gesture.direction === 'right') {
            gesture.deltaY = 0;
            gesture.angle = 0;
            gesture.distance = gesture.deltaX;
            gesture.velocityY = 0;
          }
          _this.checkScroll();
          if (!(app.layout.isMenuOpen() || e.gesture.deltaX > 0)) {
            ionic.views.ListView.prototype._handleDrag.apply(_this.ionicView, arguments);
            e.preventDefault();
            return e.stopPropagation();
          }
        };
      })(this)
    });
  };

  FolderView.prototype.onChange = function() {
    var message;
    app.layout.ionicScroll.resize();
    this.$('#empty-message').remove();
    if (_.size(this.views) === 0) {
      message = this.collection.notloaded ? 'loading' : this.collection.isSearch() ? 'no results' : 'this folder is empty';
      return $('<li class="item" id="empty-message">').text(t(message)).appendTo(this.$el);
    } else if (!this.collection.allPagesLoaded) {
      return $('<li class="item" id="empty-message">').text(t('loading')).appendTo(this.$el);
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
    var op;
    op = new ionic.SlideDrag({
      el: this.ionicView.el,
      canSwipe: function() {
        return true;
      }
    });
    op.start({
      target: event.target
    });
    if (op._currentDrag.startOffsetX === 0) {
      op.end({
        gesture: {
          deltaX: 0 - op._currentDrag.buttonsWidth,
          direction: 'right'
        }
      });
      ionic.requestAnimationFrame((function(_this) {
        return function() {
          return _this.ionicView._lastDragOp = op;
        };
      })(this));
    } else {
      this.ionicView.clearDragEffects();
    }
    event.preventDefault();
    return event.stopPropagation();
  };

  FolderView.prototype.checkScroll = function() {
    var triggerPoint;
    triggerPoint = $('#viewsPlaceholder').height() * 2;
    if (app.layout.ionicScroll.getValues().top + triggerPoint > app.layout.ionicScroll.getScrollMax().top) {
      return this.loadMore();
    }
  };

  FolderView.prototype.loadMore = function(callback) {
    if (!this.collection.notLoaded && !this.isLoading && !this.collection.allPagesLoaded) {
      this.isLoading = true;
      return this.collection.loadNextPage((function(_this) {
        return function(err) {
          _this.isLoading = false;
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    }
  };

  return FolderView;

})(CollectionView);

});

require.register("views/folder_line", function(exports, require, module) {
var BaseView, FolderLineView, log,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

log = require('/lib/persistent_log')({
  prefix: "FolderLineView",
  date: true
});

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
    icon.removeClass('ion-ios7-download-outline');
    icon.append(klass);
    return (_ref = this.parent) != null ? (_ref1 = _ref.ionicView) != null ? _ref1.clearDragEffects() : void 0 : void 0;
  };

  FolderLineView.prototype.displayProgress = function() {
    this.downloading = true;
    this.setCacheIcon('<img src="img/spinner-grey.svg"></img>');
    this.progresscontainer = $('<div class="item-progress"></div>').append(this.progressbar = $('<div class="item-progress-bar"></div>'));
    return this.progresscontainer.appendTo(this.$el);
  };

  FolderLineView.prototype.hideProgress = function(err, incache) {
    var version, _ref;
    this.downloading = false;
    if (err) {
      alert(err);
    }
    incache = app.replicator.fileInFileSystem(this.model.attributes);
    version = app.replicator.fileVersion(this.model.attributes);
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
    if ((_ref = this.progresscontainer) != null) {
      _ref.remove();
    }
    return this.render();
  };

  FolderLineView.prototype.updateProgress = function(done, total) {
    var _ref;
    return (_ref = this.progressbar) != null ? _ref.css('width', (100 * done / total) + '%') : void 0;
  };

  FolderLineView.prototype.getOnDownloadedCallback = function(callback) {
    callback = callback || function() {};
    return (function(_this) {
      return function(err, url) {
        _this.hideProgress();
        if (err) {
          log.error(err);
          return alert(t(err.message));
        }
        _this.model.set({
          incache: true
        });
        _this.model.set({
          version: app.replicator.fileVersion(_this.model.attributes)
        });
        return callback(err, url);
      };
    })(this);
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
    return app.replicator.getBinary(this.model.attributes, this.updateProgress, this.getOnDownloadedCallback((function(_this) {
      return function(err, url) {
        app.backFromOpen = true;
        return ExternalFileUtil.openWith(url, '', void 0, function(success) {}, function(err) {
          if (0 === (err != null ? err.indexOf('No Activity found') : void 0)) {
            err = t('no activity found');
          }
          alert(err.message);
          return log.error(err);
        });
      };
    })(this)));
  };

  FolderLineView.prototype.addToCache = function() {
    if (this.downloading) {
      return true;
    }
    this.displayProgress();
    if (this.model.isFolder()) {
      return app.replicator.getBinaryFolder(this.model.attributes, this.updateProgress, this.getOnDownloadedCallback());
    } else {
      return app.replicator.getBinary(this.model.attributes, this.updateProgress, this.getOnDownloadedCallback());
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

  FolderLineView.prototype.mimeClasses = {
    'application/octet-stream': 'type-file',
    'application/x-binary': 'type-binary',
    'text/plain': 'type-text',
    'text/richtext': 'type-text',
    'application/x-rtf': 'type-text',
    'application/rtf': 'type-text',
    'application/msword': 'type-text',
    'application/x-iwork-pages-sffpages': 'type-text',
    'application/mspowerpoint': 'type-presentation',
    'application/vnd.ms-powerpoint': 'type-presentation',
    'application/x-mspowerpoint': 'type-presentation',
    'application/x-iwork-keynote-sffkey': 'type-presentation',
    'application/excel': 'type-spreadsheet',
    'application/x-excel': 'type-spreadsheet',
    'aaplication/vnd.ms-excel': 'type-spreadsheet',
    'application/x-msexcel': 'type-spreadsheet',
    'application/x-iwork-numbers-sffnumbers': 'type-spreadsheet',
    'application/pdf': 'type-pdf',
    'text/html': 'type-code',
    'text/asp': 'type-code',
    'text/css': 'type-code',
    'application/x-javascript': 'type-code',
    'application/x-lisp': 'type-code',
    'application/xml': 'type-code',
    'text/xml': 'type-code',
    'application/x-sh': 'type-code',
    'text/x-script.python': 'type-code',
    'application/x-bytecode.python': 'type-code',
    'text/x-java-source': 'type-code',
    'application/postscript': 'type-image',
    'image/gif': 'type-image',
    'image/jpg': 'type-image',
    'image/jpeg': 'type-image',
    'image/pjpeg': 'type-image',
    'image/x-pict': 'type-image',
    'image/pict': 'type-image',
    'image/png': 'type-image',
    'image/x-pcx': 'type-image',
    'image/x-portable-pixmap': 'type-image',
    'image/x-tiff': 'type-image',
    'image/tiff': 'type-image',
    'audio/aiff': 'type-audio',
    'audio/x-aiff': 'type-audio',
    'audio/midi': 'type-audio',
    'audio/x-midi': 'type-audio',
    'audio/x-mid': 'type-audio',
    'audio/mpeg': 'type-audio',
    'audio/x-mpeg': 'type-audio',
    'audio/mpeg3': 'type-audio',
    'audio/x-mpeg3': 'type-audio',
    'audio/wav': 'type-audio',
    'audio/x-wav': 'type-audio',
    'video/avi': 'type-video',
    'video/mpeg': 'type-video',
    'video/mp4': 'type-video',
    'application/zip': 'type-archive',
    'multipart/x-zip': 'type-archive',
    'multipart/x-zip': 'type-archive',
    'application/x-bzip': 'type-archive',
    'application/x-bzip2': 'type-archive',
    'application/x-gzip': 'type-archive',
    'application/x-compress': 'type-archive',
    'application/x-compressed': 'type-archive',
    'application/x-zip-compressed': 'type-archive',
    'application/x-apple-diskimage': 'type-archive',
    'multipart/x-gzip': 'type-archive'
  };

  return FolderLineView;

})(BaseView);

});

require.register("views/layout", function(exports, require, module) {
var BaseView, BreadcrumbsView, FolderView, Layout, Menu,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

FolderView = require('./folder');

Menu = require('./menu');

BreadcrumbsView = require('./breadcrumbs');

module.exports = Layout = (function(_super) {
  __extends(Layout, _super);

  function Layout() {
    this.onBackButtonClicked = __bind(this.onBackButtonClicked, this);
    this.onSearchButtonClicked = __bind(this.onSearchButtonClicked, this);
    this.onMenuButtonClicked = __bind(this.onMenuButtonClicked, this);
    this.setTitle = __bind(this.setTitle, this);
    this.setBackButton = __bind(this.setBackButton, this);
    this.closeMenu = __bind(this.closeMenu, this);
    this.isMenuOpen = __bind(this.isMenuOpen, this);
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
        return _this.spinner.toggle(inSync || inBackup);
      };
    })(this));
    OpEvents = 'change:inBackup change:backup_step change:backup_step_done';
    return this.listenTo(app.replicator, OpEvents, _.debounce((function(_this) {
      return function() {
        var step, text;
        step = app.replicator.get('backup_step');
        if (step && (step !== 'pictures_scan')) {
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
    this.menu = new Menu();
    this.menu.render();
    this.$el.append(this.menu.$el);
    this.container = this.$('#container');
    this.viewsPlaceholder = this.$('#viewsPlaceholder');
    this.viewsBlock = this.viewsPlaceholder.find('.scroll');
    this.backButton = this.container.find('#btn-back');
    this.menuButton = this.container.find('#btn-menu');
    this.iconLogo = this.container.find('#icon-logo');
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
      el: this.viewsPlaceholder[0],
      bouncing: false
    });
    this.ionicScroll.scrollTo(1, 0, true, null);
    return this.ionicScroll.scrollTo(0, 0, true, null);
  };

  Layout.prototype.isMenuOpen = function() {
    return this.controller.isOpenLeft();
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
    this.$('#breadcrumbs').remove();
    this.title.text(text);
    return this.title.show();
  };

  Layout.prototype.setBreadcrumbs = function(path) {
    var breadcrumbsView;
    this.$('#breadcrumbs').remove();
    this.title.hide();
    this.iconLogo.hide();
    breadcrumbsView = new BreadcrumbsView({
      path: path
    });
    return this.title.after(breadcrumbsView.render().$el);
  };

  Layout.prototype.transitionTo = function(view) {
    var $next, currClass, menuEnabled, nextClass, transitionend, type, _ref;
    this.closeMenu();
    $next = view.render().$el;
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
      this.currentView = view;
      return this.ionicScroll.scrollTo(0, 0, false, null);
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
          return _this.ionicScroll.scrollTo(0, 0, false, null);
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
    if (this.isMenuOpen()) {
      return this.closeMenu();
    } else if (location.href.indexOf('#folder/') === (location.href.length - 8)) {
      if (window.confirm(t("confirm exit message"))) {
        return navigator.app.exitApp();
      }
    } else {
      return window.history.back();
    }
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
      'click #input-pass': 'doComplete',
      "click a[target='_system']": 'openInSystemBrowser'
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

  LoginView.prototype.afterRender = function() {
    this.$('.welcome').html(t('cozy welcome'));
    this.$('.welcome-message').html(t('cozy welcome message'));
    return this.$('.no-account').html(t('cozy welcome no account'));
  };

  LoginView.prototype.doComplete = function() {
    var url;
    url = this.$('#input-url').val();
    if (url.indexOf('.') === -1 && url.length > 0) {
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
      return this.displayError(t('all fields are required'));
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
    this.error = $('<div>').addClass('error-msg');
    this.error.html(text);
    return this.$(field || '#btn-save').before(this.error);
  };

  LoginView.prototype.openInSystemBrowser = function(e) {
    window.open(e.currentTarget.href, '_system', '');
    e.preventDefault();
    return false;
  };

  return LoginView;

})(BaseView);

});

require.register("views/menu", function(exports, require, module) {
var BaseView, Menu, log,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseView = require('../lib/base_view');

log = require('/lib/persistent_log')({
  prefix: "Menu",
  date: true
});

module.exports = Menu = (function(_super) {
  __extends(Menu, _super);

  function Menu() {
    this.doSearchIfEnter = __bind(this.doSearchIfEnter, this);
    return Menu.__super__.constructor.apply(this, arguments);
  }

  Menu.prototype.id = 'menu';

  Menu.prototype.className = 'menu menu-left';

  Menu.prototype.template = require('../templates/menu');

  Menu.prototype.events = {
    'click #close-menu': 'closeMenu',
    'click #syncButton': 'backup',
    'click #btn-search': 'doSearch',
    'click a.item': 'closeMenu',
    'keydown #search-input': 'doSearchIfEnter'
  };

  Menu.prototype.afterRender = function() {
    this.syncButton = this.$('#syncButton');
    return this.backupButton = this.$('#backupButton');
  };

  Menu.prototype.closeMenu = function() {
    return app.layout.closeMenu();
  };

  Menu.prototype.sync = function() {
    if (app.replicator.get('inSync')) {
      return;
    }
    return app.replicator.sync({}, function(err) {
      var _ref, _ref1;
      if (err) {
        log.error(err);
        alert(t(err.message != null ? err.message : "no connection"));
      }
      return (_ref = app.layout.currentView) != null ? (_ref1 = _ref.collection) != null ? _ref1.fetch() : void 0 : void 0;
    });
  };

  Menu.prototype.backup = function() {
    app.layout.closeMenu();
    if (app.replicator.get('inBackup')) {
      return this.sync();
    } else {
      return app.replicator.backup({
        force: false
      }, (function(_this) {
        return function(err) {
          var _ref, _ref1;
          if (err) {
            log.error(err);
            alert(t(err.message));
            return;
          }
          if ((_ref = app.layout.currentView) != null) {
            if ((_ref1 = _ref.collection) != null) {
              _ref1.fetch();
            }
          }
          return _this.sync();
        };
      })(this));
    }
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

require.register("views/notifications", function(exports, require, module) {
var Notifications, log,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

log = require('/lib/persistent_log')({
  prefix: "notifications",
  date: true
});

module.exports = Notifications = (function() {
  _.extend(Notifications.prototype, Backbone.Events);

  function Notifications(options) {
    this.showNotification = __bind(this.showNotification, this);
    this.markAsShown = __bind(this.markAsShown, this);
    this.fetch = __bind(this.fetch, this);
    this.onSync = __bind(this.onSync, this);
    this.activate = __bind(this.activate, this);
    options = options || {};
    this.initialize.apply(this, arguments);
  }

  Notifications.prototype.initialize = function() {
    var config;
    config = app.replicator.config;
    this.listenTo(config, 'change:cozyNotifications', this.activate);
    return this.activate(config, config.get('cozyNotifications'));
  };

  Notifications.prototype.activate = function(config, activate) {
    if (activate) {
      this.listenTo(app.replicator, 'change:inSync', this.onSync);
      return this.onSync();
    } else {
      return this.stopListening(app.replicator, 'change:inSync');
    }
  };

  Notifications.prototype.onSync = function() {
    var inSync;
    inSync = app.replicator.get('inSync');
    if (!inSync) {
      return this.fetch();
    }
  };

  Notifications.prototype.fetch = function() {
    return app.replicator.db.query('NotificationsTemporary', {
      include_docs: true
    }, (function(_this) {
      return function(err, notifications) {
        return notifications.rows.forEach(function(notification) {
          return _this.showNotification(notification.doc);
        });
      };
    })(this));
  };

  Notifications.prototype.markAsShown = function(notification) {
    return app.replicator.db.remove(notification, function(err) {
      if (err) {
        return log.error("Error while removing notification.", err);
      }
    });
  };

  Notifications.prototype.showNotification = function(notification) {
    var id;
    id = parseInt(notification._id.slice(-7), 16);
    if (isNaN(id)) {
      id = notification.publishDate % 10000000;
    }
    cordova.plugins.notification.local.schedule({
      id: id,
      message: notification.text,
      title: "Cozy - " + (notification.app || 'Notification'),
      autoCancel: true
    });
    return this.markAsShown(notification);
  };

  return Notifications;

})();

});


//# sourceMappingURL=app.js.map