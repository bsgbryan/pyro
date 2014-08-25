Overview
========

`pyro` provides a high level dsl for interacting with a Firebase datastore.

All `pyro` calls return promises.

How to use
==========

`pyro` uses two environment variables: `FIREBASE_ROOT` and `FIREBASE_KEY`. `FIREBASE_ROOT` is
required. `FIREBASE_KEY` is only required for Firesbases with 
[security rules](https://www.firebase.com/docs/security/guide.html "Securing your data").

get
---

`get` is how you read data. You pass it the location to the data you want and it returns a promise.
The promise resolves with the value at the location you specified.

Below is an example:

__NOTE__ _The `FIREBASE_ROOT` and `FIREBASE_KEY` variables are set before we call `require`_

```javascript
  var pyro = require('pyro')

  pyro.
    get('users/barney/friends/fred').
    then(function (value) {
      // Value is whatever data is stored at the /users/barney/friends/fred location
    })
```

set
---

`set` is how you insert and overwrite data. `set` assigns the value passed to the location specified. It 
returns a promise that is resolved `true` when the value has been set. The location's priority is set
using the `priority` method.

Below is an example:

```javascript
  var pyro = require('pyro')

  pyro.
    set('questions/life the universe and everything', { answer: 42 }).
    then(function (success) {
      if (success)
        do('...') // Ummm, I don't know, actually...
    })
```

add
---

`add` has the following behaviors:

1. It only adds a value if one does not already exist at the specified location.
2. It maintains a `count` property alongisde added values. `add` assumes it is operating on a list.
`count` provides an easy way to know how many items exist in the list being added to.

Below is an example:

```javascript
  var pyro = require('pyro')

  pyro.
    add('users/fred/friends/barney', { years_known: 42 }).
    then(function (added) {
      if (added)
        console.log('Recorded friend')
      else
        console.log('Friend already recorded, nothing to do')
    })
```

The result of this call (assuming it's the first of fred's friends we've added) would be:

```
/users/fred/friends/barney/{ years_known: 42 }
                   /count/1
```

The following call:

```javascript
  var pyro = require('pyro')

  pyro.
    add('users/fred/friends/shemp', { years_known: -650000000 }).
    then(function (added) {
      if (added)
        console.log('Recorded friend')
      else
        console.log('Friend already recorded, nothing to do')
    })
```

Would result in the following:

```
/users/fred/friends/barney/{ years_known: 42 }
                   /shemp/{ years_known: -650000000 }
                   /count/2
```

priority
--------

`priority` is used internally to set a location's priority. `set`, `add`, and `touch` all use `priority`. The default behavior is to return the value of `Date.now()`. If you need different behavior simply
override this method with a function that returns an appropriate value.

`priority`'s signature is:

```javascript
  function priority(location, value) {
    return // Value that can be used for sorting/searching
  }
```

The `location` parameter is the location being prioritized.

The `value` parameter is the value assigned to the location specified. `touch` does not pass this parameter.

touch
-----

`touch` is how you modify a location's priority. The location's priority is set using the `priority` method.

`touch` passes the path it's working on to `priority`, but does not pass a value.

```javascript
  var pyro = require('pyro')

  pyro.
    touch('users/fred/friends/barney').
    then(function (updated) {
      if (updated)
        celebrate()
    }).
    fail(function (err) {
      console.log(err)
    })
```

increment_count
---------------

`increment_count` increments the `count` property for the specified location.

It first gets the current count (initializing it to `0` if it doesn't exist) and then 
updates the count, incrementing it by one.

`increment_count` also sets a priority for the count using the `priority` method.

TODOS
=====

1. Add a `scope` property. This would be prepended to all locations so common location elements don't need
to be repeated.