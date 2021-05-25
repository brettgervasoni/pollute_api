// @flow
const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");

const app = express();
const port = process.env.PORT || 8000;

app.use(express.json({ limit: '50mb' }));
app.use(cors());

require("./routes")(app);
app.listen(port, () => {
    console.log(`We're live on ${port}`);
});