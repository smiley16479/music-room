import { NestFactory, Reflector } from '@nestjs/core';
import { AppModule } from './app.module';
import { ClassSerializerInterceptor, ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));
  const config = new DocumentBuilder()
    .setTitle('🎵 Music Room API')
    .setDescription(`
Music Room - Event-Centric Music Platform API

## 🏗️ Architecture
- **Event-Centric**: All features centralized around Events
- **Single Table Inheritance**: Playlists are Events with type='playlist'
- **Real-time Updates**: WebSocket support for live event updates
- **Location-based**: Geo-location support for events

## 📚 Main Modules
- **Events API** (/api/events) - Create, manage, and discover events
- **Playlists API** (/api/playlists) - Manage music playlists (facade to Events)
- **Authentication** (/api/auth) - User registration and login
- **Users** (/api/users) - User profiles and preferences
- **Invitations** (/api/invitations) - Event and playlist invitations

## 🎯 Quick Start
1. Authenticate with \`POST /auth/login\`
2. Create an event with \`POST /events\`
3. Join events or create playlists
4. Vote on tracks in real-time
5. Connect via WebSocket for live updates

## 🔐 Authentication
Most endpoints require JWT authentication via the \`Authorization\` header:
\`\`\`
Authorization: Bearer YOUR_JWT_TOKEN
\`\`\`

Public endpoints are marked with 🔓
    `)
    .setVersion('1.0.0')
    .setContact(
      'Music Room Team',
      'https://github.com/smiley16479/music-room',
      'support@musicroom.local',
    )
    .setLicense(
      'MIT',
      'https://opensource.org/licenses/MIT',
    )
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'JWT Token',
      },
      'jwt',
    )
    .addServer('http://localhost:3000', 'Development Server')
    .addServer('https://api.musicroom.local', 'Production Server')
    .build();
  
  const options = {
    swaggerOptions: {
      persistAuthorization: true,
      displayOperationId: true,
      filter: true,
      showExtensions: true,
      deepLinking: true,
    },
  };

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, options);
  var cors = require('cors');
  var corsOptions = {
    origin: '*',
    optionsSuccessStatus: 200, 
    credentials : true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'] // pour MAC sinon CORS (pas sur que AUthorization soit nécessaire)
  }
  app.use(cors( corsOptions ));
  app.use(cookieParser());
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
