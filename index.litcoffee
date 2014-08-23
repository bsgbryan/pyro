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
  
This will only execute once - when the module is first loaded.

    firebase.auth process.env.FIREBASE_KEY, () -> console.log 'AUTHED'

Helper to provide easy access to the last element of an array.

    Array::last = -> @[@length - 1]

sanitize
--------

Firebase does not support several characters in the url path. This method scrubs such characters.

    sanitize = (nodes) ->
      nodes
        .join '/'
        .replace /\.|#|\$|\[|\]/g, '' # These characters are not allowed by Firebase

set
---

`set` takes a path as a simple string. It does not check to see if a value exists before setting
and overrites any existing value. This is especially important because the entire node graph
beneath the node being written is replaced - meaning `foo`, `bar`, and `baz` would be overwritten
by setting `foo`. If the new `foo` value does not contain `bar` or `baz` they will just go away. 

`set` also specifies a priotity for the data's node. The priority is the time the node gets
added. This allows the node to be sorted and used in `startAt` and `endAt` Firebase queries.

    set = (value, nodes...) ->
      deferred = q.defer()

      firebase
        .child sanitize nodes
        .setWithPriority value, Date.now(), (err) ->
          if err? 
            deferred.reject context: 'readbase.set', error: err
          else
            deferred.resolve true

      deferred.promise

add
---

1. Add the specified value to the first node of the passed array
2. Increment the count for all ancestor nodes

`add` only adds the specified node and assigns it the passed value if the node does not already
exist. If the specified node (the first elements in the `nodes` array) does exist the value is
not updated, no count incrementing is done, and the promise is resolved explaining that nothing
was added.

To do the count updating we use `do_increment_count`.

    add = (value, increment_recursively, nodes...) ->
      deferred = q.defer()
      steps    = nodes.reverse()
      path     = sanitize steps

      firebase
        .child path
        .once 'value', (snapshot) ->
          val = snapshot.val()

          if val?
            deferred.resolve added: null
          else
            set value, steps
              .then (   ) -> 
                if increment_recursively
                  do_increment_count steps[0...-1]
                else
                  increment_count sanitize steps[0...-1]

              .then (   ) -> deferred.resolve added: nodes.last
              .fail (err) -> 
                console.log "error #{err}"
                deferred.reject context: 'readbase.add', error: err

      deferred.promise

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

increment_count
---------------

_this method is private_

`increment_count` is the method that actually increments the count for the specified path.

It first gets the current count (initializing it to `0` if it doesn't exist) and then 
updates the count, incrementing it by one.

`increment_count` also sets a priority for the count. The priority is the time the count was
updated. This makes it easy to determine the last time a count was updated.

    increment_count = (path) ->
      deferred = q.defer()
      count    = path + '/count'

      firebase
        .child count
        .once 'value', (snapshot) ->
          val = snapshot.val() || 0

          firebase
            .child count
            .setWithPriority ++val, Date.now(), (err) ->
              if err?
                deferred.reject context: 'increment_count', error: err
              else
                deferred.resolve()

      deferred.promise

Public interface
----------------

    module.exports = 
      set: set, 
      add: add