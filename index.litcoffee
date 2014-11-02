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

    set = (location, value, p) ->
      deferred = q.defer()
      loc      = sanitize location

      firebase
        .child sanitize loc
        .setWithPriority value, p || priority(loc, value), (err) ->
          if err? 
            deferred.reject context: 'pyro/set', error: err
          else
            deferred.resolve true

      deferred.promise

add_value
---------

1. Add the passed value to the location specified
2. Increment the list count

`add` only sets the specified value at the passed location if the node does not already exist. If 
the specified location does exist nothing is done.

    add_value = (location, value, p) ->
      deferred = q.defer()

      get location
        .then (val) ->
          if val?
            deferred.resolve false
          else
            set location, value, p
              .then (   ) -> deferred.resolve true
              .fail (err) -> deferred.reject context: 'pyro/add', error: err

      deferred.promise

add_leaf
--------

    add_leaf = (location, value, p) ->
      deferred = q.defer()

      get "#{location}/#{value}"
        .then (val) ->
          if val?
            deferred.resolve false
          else
            set "#{location}/#{value}", Date.now(), p
              .then (   ) -> deferred.resolve true
              .fail (err) -> deferred.reject context: 'pyro/add', error: err

      deferred.promise

push
----

    push = (location, value) ->
      deferred = q.defer()

      firebase
        .child location
        .push value, (err) ->
          if err?
            deferred.reject err
          else
            deferred.resolve true

      deferred.promise

find
----

    find = (path, beginning) ->
      deferred = q.defer()

      firebase
        .child sanitize path
        .startAt beginning
        .on 'child_added', (snapshot) ->
            deferred.notify 
              name:  snapshot.name()
              value: snapshot.val()

      deferred.promise

touch
-----

Update a location's priority.

    touch = (location, p) ->
      deferred = q.defer()
      loc      = sanitize location

      firebase
        .child loc
        .setPriority p || priority(loc), (err) ->
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
      loc      = sanitize location
      count    = "#{loc}/_count_"

      firebase
        .child count
        .once 'value', (snapshot) ->
          val = snapshot.val() || 0

          firebase
            .child count
            .setWithPriority ++val, priority(loc, val), (err) ->
              if err?
                deferred.reject context: 'pyro/increment_count', error: err
              else
                deferred.resolve()

      deferred.promise

priority
--------

The function used to set a location's priority.

    priority = (location, value) -> Date.now()

watch
-----

    watch = (path, event) ->
      deferred = q.defer()

      if path.indexOf('*') > 0
        deep = path.split '/'

        for step, i in deep
          if step == '*'
            node = sanitize deep[0...i].join '/'
            firebase
              .child node
              .on "child_#{event}", (snapshot) ->
                firebase
                  .child "#{node}/#{snapshot.name()}"
                  .on "child_#{event}", (snap) ->
                    deferred.notify name: snap.name(), value: snap.val()
            break
      else
        firebase
          .child sanitize path
          .on "child_#{event}", (snap) ->
            deferred.notify name: snap.name(), value: snap.val()

      deferred.promise


Public interface
----------------

    module.exports = 
      get:             get
      set:             set
      push:            push
      find:            find
      watch:           watch
      priority:        priority
      add_leaf:        add_leaf
      add_value:       add_value
      increment_count: increment_count