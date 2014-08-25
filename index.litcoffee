Overview
--------

This module wraps all interation with Firebase. It provides a nice dsl to execute operations
against a Firebase datastore. It does make some assumptions - like that when you `add` something
you also want to keep track of the `count` for the list of items you just added to.

Initialization
--------------

Pull in our requires and setup our Firebase connection.

__NOTE__ _a FIREBASE_ROOT must be specified. An example would be "https://reallycool.firebaseio.com"_

    Firebase = require 'firebase'
    firebase = new Firebase process.env.FIREBASE_ROOT
    q        = require 'q'
  
This will only execute once - when the module is first loaded. It's only called if a `FIREBASE_KEY`
is provided. Otherwise `pyro` assumes you don't need to be authed.

    if process.env.FIREBASE_KEY?
      firebase.auth process.env.FIREBASE_KEY, () -> console.log 'AUTHED'

Helper to provide easy access to the last element of an array.

    Array::last = -> @[@length - 1]

sanitize
--------

Firebase does not support several characters in the url location. This method scrubs such characters.

    sanitize = (location) -> location.replace /\.|#|\$|\[|\]/g, ''

get
---

Get the value for the specified location from Firebase.

    get = (location) ->
      deferred = q.defer()

      firebase
        .child sanitize location
        .once 'value', (snapshot) -> deferred.resolve snapshot.val()

      deferred.promise

set
---

`set` takes a location as a simple string. It does not check to see if a value exists before setting
and overrites any existing value. This is especially important because the entire node graph
beneath the node being written is replaced - meaning `foo`, `bar`, and `baz` would be overwritten
by setting `foo`. If the new `foo` value does not contain `bar` or `baz` they will just go away. 

`set` also specifies a priotity for the data's node. The priority is the time the node gets
added. This allows the node to be sorted and used in `startAt` and `endAt` Firebase queries.

    set = (location, value) ->
      deferred = q.defer()

      firebase
        .child sanitize location
        .setWithPriority value, priority(location, value), (err) ->
          if err? 
            deferred.reject context: 'readbase.set', error: err
          else
            deferred.resolve true

      deferred.promise

add
---

1. Add the passed value to the location specified
2. Increment the list count

`add` only sets the specified value at the passed location if the node does not already exist. If 
the specified location does exist nothing is done.

    add = (location, value) ->
      deferred = q.defer()

      get location
        .then (val) ->
          if val?
            deferred.resolve added: false
          else
            set sanitize(location), value
              .then (   ) -> increment_count sanitize location.split('/')[0...-1].join('/')
              .then (   ) -> deferred.resolve added: true
              .fail (err) -> deferred.reject context: 'readbase.add', error: err

      deferred.promise

touch
-----

Update a location's priority.

    touch = (location) ->
      deferred = q.defer()

      firebase
        .child sanitize location
        .setPriority priority(location), (err) ->
          if err?
            deferred.reject err
          else
            deferred.resolve true

      deferred.promise

increment_count
---------------

`increment_count` increments the `count` property for the specified location.

It first gets the current count (initializing it to `0` if it doesn't exist) and then 
updates the count, incrementing it by one.

`increment_count` also sets a priority for the count using the `priority` method.

    increment_count = (location) ->
      deferred = q.defer()
      count    = location + '/count'

      firebase
        .child sanitize count
        .once 'value', (snapshot) ->
          val = snapshot.val() || 0

          firebase
            .child count
            .setWithPriority ++val, priority(location, val), (err) ->
              if err?
                deferred.reject context: 'increment_count', error: err
              else
                deferred.resolve()

      deferred.promise

priority
--------

The function used to set a location's priority.

    priority = (location, value) -> Date.now()

Public interface
----------------

    module.exports = 
      get:             get
      set:             set 
      add:             add
      priority:        priority
      increment_count: increment_count