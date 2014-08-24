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
    get('fred', 'friends', 'barney', 'users').
    then(function (value) {
      // Value is whatever data is stored at the /users/barney/friends/fred path
    })
```

set
---

`set` is how you insert and overwrite data. `set` assigns the value passed to the path specified. It 
returns a promise that is resolved `true` when the value has been set. The priority of the value set
is `Date.now()` to help with sorting/searching.

Below is an exmaple:

```javascript
  var pyro = require('pyro')

  pyro.
    set({ answer: 42 }, 'life the universe and everything', 'questions').
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
3. Added items are assigned a priority of `Date.now()` to help with sorting/searching.
4. `add` can optionally maintain `count` properties from the leaf node passed to the root node. This
behavior is managed via the second argument - `increment_recursively`.

Below is an example:

```javascript
  var pyro = require('pyro')

  pyro.
    add({ years_known: 42 }, false, 'barney', 'friends', 'fred', 'users').
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
    add({ years_known: -650000000 }, false, 'shemp', 'friends', 'fred', 'users').
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

touch
-----

Touch is how you modify a path's priority. Currently a path's priority is udpated to `Date.now()`.

```javascript
  var pyro = require('pyro')

  pyro.
    touch('barney', 'friends', 'fred', 'users').
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
2. Add support for custom priority management.