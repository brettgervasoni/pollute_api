# build in a seperate container
FROM node:latest as builder

COPY package*.json ./
COPY . .

RUN npm install -g nodemon babel-cli
RUN npm install
RUN npm run prepare

# launch new container copy over app
FROM node:latest

WORKDIR /usr/src/app
COPY --from=builder node_modules node_modules
COPY --from=builder dist dist
COPY . .

CMD [ "npm", "run", "prod" ]