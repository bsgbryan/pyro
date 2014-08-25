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

Firebase does not support several characters in the url path. This method scrubs such characters.

    sanitize = (path) -> path.replace /\.|#|\$|\[|\]/g, ''

set
---

`set` takes a path as a simple string. It does not check to see if a value exists before setting
and overrites any existing value. This is especially important because the entire node graph
beneath the node being written is replaced - meaning `foo`, `bar`, and `baz` would be overwritten
by setting `foo`. If the new `foo` value does not contain `bar` or `baz` they will just go away. 

`set` also specifies a priotity for the data's node. The priority is the time the node gets
added. This allows the node to be sorted and used in `startAt` and `endAt` Firebase queries.

    set = (path, value) ->
      deferred = q.defer()

      firebase
        .child sanitize path
        .setWithPriority value, priority(), (err) ->
          if err? 
            deferred.reject context: 'readbase.set', error: err
          else
            deferred.resolve true

      deferred.promise

add
---

1. Add the passed value to the path specified
2. Increment the list count

`add` only sets the specified value at the passed path if the node does not already exist. If 
the specified path does exist nothing is done.

    add = (path, value) ->
      deferred = q.defer()

      get path
        .then (val) ->
          if val?
            deferred.resolve added: false
          else
            set value, steps
              .then (   ) -> increment_count sanitize steps[0...-1]
              .then (   ) -> deferred.resolve added: true
              .fail (err) -> deferred.reject context: 'readbase.add', error: err

      deferred.promise

get
---

Get the value for the specified path from Firebase.

    get = (path) ->
      deferred = q.defer()

      firebase
        .child sanitize path
        .once 'value', (snapshot) -> deferred.resolve snapshot.val()

      deferred.promise

touch
-----

Update a path's priority.

    touch = (path) ->
      deferred = q.defer()

      firebase
        .child sanitize path
        .setPriority priority(), (err) ->
          if err?
            deferred.reject err
          else
            deferred.resolve true

      deferred.promise

increment_count
---------------

`increment_count` is the method that actually increments the count for the specified path.

It first gets the current count (initializing it to `0` if it doesn't exist) and then 
updates the count, incrementing it by one.

`increment_count` also sets a priority for the count. The priority is the time the count was
updated. This makes it easy to determine the last time a count was updated.

    increment_count = (path) ->
      deferred = q.defer()
      count    = path + '/count'

      firebase
        .child sanitize count
        .once 'value', (snapshot) ->
          val = snapshot.val() || 0

          firebase
            .child count
            .setWithPriority ++val, priority(), (err) ->
              if err?
                deferred.reject context: 'increment_count', error: err
              else
                deferred.resolve()

      deferred.promise

priority
--------

The function used to set a path's priority.

    priority = () -> Date.now()

do_increment_count
------------------

_this method is private_

This method recusively calls itself, updating counts as it goes. It builds a promise chain,
with all promises geting resolved when all node counts have been updated.

    do_increment_count = (nodes) ->
      deferred = q.defer()

      if nodes.length > 0

        increment_count sanitize nodes
          .then (   ) -> do_increment_count nodes[0...-1]
          .then (   ) -> deferred.resolve()
          .fail (err) -> deferred.reject context: 'do_increment_count', error: err
      else
        setTimeout () ->      # We use a setTimout here to force this promise to
          deferred.resolve()  # resolve after it is returned. Without this, the 
        , 0                   # caller would never get the resolve message.

      deferred.promise

Public interface
----------------

    module.exports = 
      get:             get
      set:             set 
      add:             add
      priority:        priority
      increment_count: increment_count