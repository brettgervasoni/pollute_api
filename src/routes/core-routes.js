// @flow

const _ = require('lodash');
const util = require('util');
const fetch = require('node-fetch');

// you could use a db, but for simplicity, its defined statically here
const users = [
    { name: "dolores", password: "pollute" },
    { name: "hector", password: "pollute" },
    { name: "bernard2", password: "bernard2", admin: true, debug: true },
    { name: "bernard", password: Math.random().toString(32), admin: true, debug: true } // unknown password
];

// maps json json object to user object
function find_user(json): Object {
    return users.find((user) =>
        user.name === json.username && user.password === json.password);
}

module.exports = function (app: Express) {
    app.get("/", (req, res) => {
        res.send('wow');
    });

    app.get("/api/", (req, res) => {
        res.json({ message: "login at /api/login" });
    });

    app.get("/api/fetch", (req, res) => {
        (async () => {
            const response = await fetch('https://haxx.cc/', {});
            const body = await response.text();

            console.log(body);
            res.json({ message: "login at /api/login", status: response.status });
        })();
    });

    app.post("/api/login", (req, res) => {
        var redirect = '/api/get_basic_stats';
        if ('redirect_url' in req.body) {
            redirect = req.body.redirect_url;
        }

        // get access attempt information
        const access = {
            ip: req.ip,
            timestamp: new Date(Date.now()).toString(),
            //1 - entry point
            redirect_url: redirect // the page the user was last on before timeout (if any)
        }

        if ('username' in req.body && 'password' in req.body) {
            const user = find_user(req.body); //retrieve user
            if (user) {
                //add access information
                const connected_user = _.merge({}, user, access); //2 - vulnerability, objects merged
                console.log(`* new user logged in - admin: ${connected_user.admin}`);

                //debugging the user object
                //console.log(connected_user);
                //console.log(util.inspect(connected_user.constructor.prototype, { showHidden: true }));

                var output = `Logged in as: ${connected_user.name}`;
                if (connected_user.admin) {
                    output += ', with admin privileges';
                    if (connected_user.debug)
                        output += ', and debug functionality';
                    output += `, from ${connected_user.ip}`

                    // confirm the redirect_url endpoint exists before we redirect them
                    // only validate for admin pages
                    console.log(connected_user.admin);
                    console.log(connected_user.redirect_url);

                    if (connected_user.redirect_url.toString().indexOf('/admin') > -1) {
                        (async () => {
                            const response = await fetch('https://haxx.cc/');
                            const body = await response.text();

                            console.log(body);
                            var message: {
                                message: string, redirect_res_status?: number, redirect_res_body?: number
                            } = { message: output, redirect_res_status: response.status };

                            // only valid for 200s, redirects can be a bit sus with CSRF attacks
                            if (response.status == 200) {
                                if (connected_user.debug)
                                    message.redirect_res_body = body;
                            }

                            res.json({ message: message });
                        })();
                    }
                    else {
                        res.json({ message: output, redirect_url: 'only redirects to admin endpoints are allowed' });
                    }
                }
                else {
                    output += `, from ${connected_user.ip}`;
                    res.json({ message: output });
                }
            }
            else {
                var username = 'unknown';
                if ('username' in req.body) {
                    username = req.body.username;
                }

                // log invalid access attempt
                console.log(`! invalid login attempt for user '${username}' on ${access.timestamp} from ${access.ip}`)

                res.json({ message: 'Invalid username and password' });
            }
        }
        else {
            console.log(`! invalid login attempt with no username on ${access.timestamp} from ${access.ip}`)
            res.json({ message: "Invalid login request, send username and password parameters" });
        }
    });
};