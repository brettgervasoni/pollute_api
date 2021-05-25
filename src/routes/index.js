// @flow
const Express = require('express');
const coreRoutes = require("./core-routes");

module.exports = function (app: Express) {
    coreRoutes(app);
};