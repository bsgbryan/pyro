// Generated by CoffeeScript 1.8.0
(function() {
  var Firebase, add_leaf, add_value, biggest, count, execute_query, exist, exists, find, firebase, get, increment_count, monitor, priority, push, q, remove, sanitize, set, smallest, to, touch, unmonitor, unwatch, watch;

  Firebase = require('firebase');

  firebase = new Firebase(process.env.FIREBASE_ROOT);

  q = require('q');

  if (process.env.FIREBASE_KEY != null) {
    firebase.authWithCustomToken(process.env.FIREBASE_KEY, function() {
      return console.log('AUTHED');
    });
  }

  Array.prototype.last = function() {
    return this[this.length - 1];
  };

  sanitize = function(location) {
    return location.replace(/\.|#|\$|\[|\]/g, '');
  };

  get = function(location) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(location)).once('value', function(snapshot) {
      return deferred.resolve(snapshot.val());
    });
    return deferred.promise;
  };

  set = function(location, value, p) {
    var deferred, loc;
    deferred = q.defer();
    loc = sanitize(location);
    firebase.child(loc).setWithPriority(value, p || Date.now(), function(err) {
      if (err != null) {
        return deferred.reject(err);
      } else {
        return deferred.resolve(true);
      }
    });
    return deferred.promise;
  };

  biggest = function(path, options) {
    return execute_query('Last', path, options);
  };

  smallest = function(path, options) {
    return execute_query('First', path, options);
  };

  to = function(path, end, limit) {
    var callback, deferred, invokes;
    deferred = q.defer();
    invokes = 0;
    callback = function(snapshot) {
      deferred.notify({
        name: snapshot.key(),
        value: snapshot.val()
      }, ++invokes);
      if (invokes === limit) {
        firebase.child(sanitize(path)).off('child_changed', callback);
        return deferred.resolve();
      }
    };
    firebase.child(sanitize(path)).orderByPriority().endAt(end).limitToFirst(limit).on('child_added', callback);
    return deferred.promise;
  };

  count = function(path, end) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(path)).orderByPriority().endAt(end).once('value', function(snapshot) {
      return deferred.resolve(snapshot.numChildren());
    });
    return deferred.promise;
  };

  exists = function(path, child) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(path)).once('value', function(snapshot) {
      return deferred.resolve(snapshot.hasChild(sanitize(child)));
    });
    return deferred.promise;
  };

  exist = function(things) {
    var deferred, keys, responses, results;
    deferred = q.defer();
    keys = Object.keys(things);
    results = {};
    responses = 0;
    keys.forEach(function(key) {
      return firebase.child(sanitize(key)).once('value', function(snapshot) {
        results[key] = snapshot.hasChild(sanitize(things[key]));
        if (++responses === keys.length) {
          return deferred.resolve(results);
        }
      });
    });
    return deferred.promise;
  };

  add_value = function(location, value, p) {
    var deferred;
    deferred = q.defer();
    get(location).then(function(val) {
      if (val != null) {
        return deferred.resolve(false);
      } else {
        return set(location, value, p).then(function() {
          return deferred.resolve(true);
        }).fail(function(err) {
          return deferred.reject(err);
        });
      }
    });
    return deferred.promise;
  };

  add_leaf = function(location, value, p) {
    var deferred;
    deferred = q.defer();
    get("" + location + "/" + value).then(function(val) {
      if (val != null) {
        return deferred.resolve(false);
      } else {
        return set("" + location + "/" + value, Date.now(), p).then(function() {
          return deferred.resolve(true);
        }).fail(function(err) {
          return deferred.reject(err);
        });
      }
    });
    return deferred.promise;
  };

  push = function(location, value) {
    var deferred;
    deferred = q.defer();
    firebase.child(location).push(value, function(err) {
      if (err != null) {
        return deferred.reject(err);
      } else {
        return deferred.resolve(true);
      }
    });
    return deferred.promise;
  };

  find = function(path, options) {
    var deferred, key;
    deferred = q.defer();
    key = Object.keys(options)[0];
    firebase.child(sanitize(path)).orderByChild(key).startAt(options[key]).on('child_added', function(snapshot) {
      return deferred.notify({
        name: snapshot.key(),
        value: snapshot.val()
      });
    });
    return deferred.promise;
  };

  touch = function(location, p) {
    var deferred, loc;
    deferred = q.defer();
    loc = sanitize(location);
    firebase.child(loc).setPriority(p || priority(loc), function(err) {
      if (err != null) {
        return deferred.reject(err);
      } else {
        return deferred.resolve(true);
      }
    });
    return deferred.promise;
  };

  increment_count = function(location) {
    var deferred, loc;
    deferred = q.defer();
    loc = sanitize(location);
    count = "" + loc + "/_count_";
    firebase.child(count).once('value', function(snapshot) {
      var val;
      val = snapshot.val() || 0;
      return firebase.child(count).setWithPriority(++val, priority(loc, val), function(err) {
        if (err != null) {
          return deferred.reject({
            context: 'pyro/increment_count',
            error: err
          });
        } else {
          return deferred.resolve();
        }
      });
    });
    return deferred.promise;
  };

  priority = function(location, value) {
    return Date.now();
  };

  watch = function(path, event) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(path)).on("child_" + event, function(snap) {
      return deferred.notify({
        name: snap.key(),
        value: snap.val()
      });
    });
    return deferred.promise;
  };

  unwatch = function(path, event, listener) {
    return firebase.child(sanitize(path)).off("child_" + event, listener);
  };

  monitor = function(path) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(path)).once('value', function(snapshot) {
      return deferred.notify({
        event: 'added',
        value: {
          name: snapshot.key(),
          value: snapshot.val(),
          priority: snapshot.getPriority()
        }
      });
    });
    firebase.child(sanitize(path)).on('child_changed', function(snapshot) {
      return deferred.notify({
        event: 'updated',
        value: {
          name: snapshot.key(),
          value: snapshot.val(),
          priority: snapshot.getPriority()
        }
      });
    });
    return deferred.promise;
  };

  unmonitor = function(path) {
    return firebase.child(sanitize(path)).off('child_changed');
  };

  remove = function(path) {
    var deferred;
    deferred = q.defer();
    firebase.child(sanitize(path)).remove(function() {
      return deferred.resolve();
    });
    return deferred.promise;
  };

  execute_query = function(mode, path, options) {
    var deferred, query;
    deferred = q.defer();
    query = firebase.child(sanitize(path));
    if (options.startAt != null) {
      query.startAt(options.startAt);
    }
    if (options.key != null) {
      query.orderByChild(options.key);
    } else {
      query.orderByPriority();
    }
    if (options.limit != null) {
      query["limitTo" + mode](parseInt(options.limit, 10));
    }
    query.once('value', function(snapshot) {
      var out;
      out = [];
      snapshot.forEach(function(snap) {
        out.push({
          name: snap.key(),
          value: snap.val(),
          priority: snap.getPriority()
        });
        return false;
      });
      return deferred.resolve(options.order === 'desc' ? out.reverse() : out);
    });
    return deferred.promise;
  };

  module.exports = {
    to: to,
    get: get,
    set: set,
    push: push,
    find: find,
    watch: watch,
    touch: touch,
    count: count,
    exist: exist,
    exists: exists,
    remove: remove,
    unwatch: unwatch,
    monitor: monitor,
    biggest: biggest,
    smallest: smallest,
    priority: priority,
    add_leaf: add_leaf,
    unmonitor: unmonitor,
    add_value: add_value,
    increment_count: increment_count
  };

}).call(this);
