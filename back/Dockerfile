FROM node:24 AS development

# Install yt-dlp and ffmpeg for YouTube audio extraction
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    && pip3 install --break-system-packages yt-dlp \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

# CMD [ "npm", "run", "start:dev" ] // Mis dans le docker-compose mnt
