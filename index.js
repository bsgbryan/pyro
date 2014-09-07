// Generated by CoffeeScript 1.7.1
(function() {
  var Firebase, add_leaf, add_value, firebase, get, increment_count, priority, push, q, sanitize, set, touch;

  Firebase = require('firebase');

  firebase = new Firebase(process.env.FIREBASE_ROOT);

  q = require('q');

  if (process.env.FIREBASE_KEY != null) {
    firebase.auth(process.env.FIREBASE_KEY, function() {
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
    firebase.child(sanitize(loc)).setWithPriority(value, p || priority(loc, value), function(err) {
      if (err != null) {
        return deferred.reject({
          context: 'pyro/set',
          error: err
        });
      } else {
        return deferred.resolve(true);
      }
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
        return set(sanitize(location), value, p).then(function() {
          return increment_count(sanitize(location.split('/').slice(0, -1).join('/')));
        }).then(function() {
          return deferred.resolve(true);
        }).fail(function(err) {
          return deferred.reject({
            context: 'pyro/add',
            error: err
          });
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
        return set(sanitize("" + location + "/" + value), Date.now(), p).then(function() {
          return deferred.resolve(true);
        }).fail(function(err) {
          return deferred.reject({
            context: 'pyro/add',
            error: err
          });
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
    var count, deferred, loc;
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

  module.exports = {
    get: get,
    set: set,
    add_leaf: add_leaf,
    add_value: add_value,
    priority: priority,
    increment_count: increment_count
  };

}).call(this);
