Overview
========

`pyro` provides a high level dsl for interacting with a Firebase datastore.

How to use
==========

`pyro` uses two environment variables: `FIREBASE_ROOT` and `FIREBASE_KEY`. `FIREBASE_ROOT` is
required. `FIREBASE_KEY` is only required for Firesbases with auth rules.

get
---

`get` is how you read data from Firebase. You pass it the path to the data you want as an array and
it returns a promise. The promise resolves to the value at the path you specified.

Below is an example:

__NOTE__ _The `FIREBASE_ROOT` and `FIREBASE_KEY` variables are set before we call `require`_

```javascript
  var pyro = require('pyro')

  pyro.
    get('users/barney/friends/fred').
    then(function (value) {
      // Value is whatever data is stored at the /users/barney/friends/fred path
    })
```

set
---

`set` is how you insert and overwrite data. `set` assigns the value passed to the path specified. It 
returns a promise that is resolved `true` when the value has been set. The path's priority is set
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

`add` is like set++.

1. It only adds a value if one does not already exist at the specified path.
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

`priority` is used to set a path's priority. `set`, `add`, and `touch` all use `priority`. The 
default behavior is to return the value of `Date.now()`. If you need different behavior simply
override this method with a function that returns an appropriate value.

touch
-----

Touch is how you modify a path's priority. The path's priority is set using the `priority` method.

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

TODOS
=====

1. Add a `scope` property. This would be prepended to all paths so common path elements don't need
to be repeated.