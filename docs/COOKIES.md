Policies
===

* No first-party cookies for anonymous users. First-party cookies are those set by buildbarbuda.org.
    * There may be 3rd party cookies, like Google Analytics cookies.
* There will be first-party cookies for users who have registered to add content. These cookies are required to log in and maintain their sessions.

Developer Implementation
===

Where cookies are set
---

[buildbarbuda.org Loadbalancing cookie](../filesystem/var/www/html/sites/all/modules/loadbalancing_cookie/loadbalancing_cookie.module)

Where cookies are used
---

`applications/site/site-aws/cloudformation.yaml`

Verification
---

`applications/site/tests/test_headers.py` test_no_cookies_for_anonymous_users
