FROM node:22 AS development

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

# CMD [ "npm", "run", "start:dev" ] // Mis dans le docker-compose mnt
