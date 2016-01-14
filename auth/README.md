# Authentication and Authorization

It is possible to use Mindbender with authentication and grant access only
to users which you have authorized.

## Authentication

You first have to create an account at
```
https://console.developers.google.com/project
```

*  Select ```APIs & auth``` on the left, and then ```Credentials```.
*  Click ```Add Credentials```. Choose a name.
*  Add an ```Authorized JavaScript origin```. For testing, add
   ```
   http://localhost:8000
   ```
*  Add an ```Authorized redirect URI```. For testing, add
   ```
   http://localhost:8000/auth/google/callback
   ```
*  Copy the Client ID and Client secret shown at the top into your
   ```
   mindbender/auth/auth-api.coffee
   ```
*  Finally, choose if you would like to require users to authenticate
   by setting
   ```
   REQUIRES_LOGIN = true
   ```

## Authorization

In addition to requiring users to authenticate, you can also
selectively grant access to some users.

*  Make sure you are running the authorization mongo backend, by
   executing
   ```
   mindbender auth start
   ```
   Note: You can run ```mindbender auth stop``` to quit this backend.

*  In ```mindbender/auth/auth-api.coffee``` set variable ```AUTHORIZED_ONLY = true```.

*  Now you can use the following commands to define your set of authorized
   users.

   ```
   # Show authorized users:
   curl http://localhost:8000/api/auth/authorized

   # Add authorized user:
   curl -H "Content-Type: application/json" -d '{"googleID":"000000000000000000000"}' http://localhost:8000/api/auth/authorized

   # Remove authorized user:
   curl -X DELETE http://localhost:8000/api/auth/authorized/000000000000000000000
   ```
*  Users will see their Google ID when their login fails, with a message to
   request access by sending an email to ```REQUEST_EMAIL```.


