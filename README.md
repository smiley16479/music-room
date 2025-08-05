# Architecture Music Room Application
## Vue d'ensemble du système

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SvelteKit     │    │    NestJS       │    │     MySQL       │
│   Frontend      │◄──►│    Backend      │◄──►│   Database      │
│                 │    │                 │    │                 │
│ - Authentication│    │ - REST API      │    │ - Users         │
│ - Real-time UI  │    │ - Socket.IO     │    │ - Events        │
│ - Music Player  │    │ - TypeORM       │    │ - Playlists     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │
        │              ┌─────────────────┐
        │              │  External APIs  │
        └──────────────┤                 │
                       │ - Deezer API    │
                       │ - Google OAuth  │
                       │ - Facebook SDK  │
                       └─────────────────┘
```

## Structure des dossiers

### Backend (NestJS)
```
music-room-backend/
├── src/
│   ├── auth/                    # Module d'authentification
│   │   ├── guards/
│   │   ├── strategies/          # JWT, Google, Facebook
│   │   └── decorators/
│   ├── users/                   # Gestion des utilisateurs
│   │   ├── entities/
│   │   ├── dto/
│   │   └── services/
│   ├── events/                  # Module Music Track Vote
│   │   ├── entities/
│   │   ├── gateways/           # Socket.IO
│   │   └── services/
│   ├── playlists/              # Module Playlist Editor
│   │   ├── entities/
│   │   ├── gateways/           # WebSocket real-time
│   │   └── services/
│   ├── devices/                # Module Music Control Delegation
│   │   ├── entities/
│   │   └── services/
│   ├── music/                  # Intégration Deezer
│   │   ├── services/
│   │   └── interfaces/
│   ├── common/                 # Guards, pipes, filters
│   │   ├── guards/
│   │   ├── pipes/
│   │   └── decorators/
│   └── database/               # Configuration TypeORM
├── config/                     # Variables d'environnement
└── test/
```

### Frontend (SvelteKit)
```
music-room-frontend/
├── src/
│   ├── lib/
│   │   ├── components/         # Composants réutilisables
│   │   │   ├── auth/
│   │   │   ├── music/
│   │   │   ├── events/
│   │   │   └── playlists/
│   │   ├── stores/            # Stores Svelte
│   │   │   ├── auth.ts
│   │   │   ├── socket.ts
│   │   │   └── music.ts
│   │   ├── services/          # API calls
│   │   │   ├── api.ts
│   │   │   └── socket.ts
│   │   └── utils/
│   ├── routes/
│   │   ├── (auth)/           # Routes protégées
│   │   │   ├── dashboard/
│   │   │   ├── events/
│   │   │   ├── playlists/
│   │   │   └── profile/
│   │   ├── auth/             # Login, register
│   │   └── +layout.svelte
│   └── app.html
├── static/
└── tests/
```

## Architecture des données

### Entités principales

1. **User**
   - id, email, password, socialIds
   - profile (public, friends, private)
   - musicPreferences
   - devices[]

2. **Event** (Music Track Vote)
   - id, name, description, location
   - visibility (public/private)
   - licenseType (open/invited/location-based)
   - playlist, votes[], participants[]

3. **Playlist** (Playlist Editor)
   - id, name, description
   - visibility, licenseType
   - tracks[], collaborators[]
   - realTimeUpdates via Socket.IO

4. **Device** (Music Control Delegation)
   - id, name, type, userId
   - delegatedTo, permissions[]

5. **Vote, Track, Invitation, etc.**

## Communication temps réel

### Socket.IO Events

#### Events (Music Track Vote)
- `join-event` / `leave-event`
- `suggest-track` / `vote-track`
- `playlist-updated` / `now-playing`

#### Playlists (Collaborative Editor)
- `join-playlist` / `leave-playlist`
- `add-track` / `remove-track` / `reorder-tracks`
- `playlist-updated` / `user-joined` / `user-left`

#### Devices (Control Delegation)
- `device-status` / `delegate-control`
- `revoke-control` / `control-updated`

## Sécurité et permissions

### Authentification
- JWT tokens avec refresh
- OAuth Google/Facebook
- Rate limiting par IP/user

### Autorisation
- Guards basés sur les rôles
- Validation des permissions temps réel
- Vérification de géolocalisation (si activée)

### Validation des données
- DTO avec class-validator
- Sanitization des entrées
- Validation des coordonnées GPS

## APIs externes

### Deezer API
- Recherche de musique
- Métadonnées des tracks
- Aperçus audio (30 secondes)
- Gestion des playlists

### Services d'authentification
- Google OAuth 2.0
- Facebook Login SDK
- Validation des tokens côté serveur

## Technologies et patterns

### Backend
- **NestJS** : Framework modulaire
- **TypeORM** : ORM avec décorateurs
- **Socket.IO** : WebSocket temps réel
- **Passport** : Stratégies d'authentification
- **Class-validator** : Validation des DTO

### Frontend
- **SvelteKit** : Framework full-stack
- **Socket.IO Client** : Communication temps réel
- **Axios** : Requêtes HTTP
- **Tailwind CSS** : Styling utilitaire
- **Svelte Stores** : Gestion d'état réactive

### Base de données
- **MySQL** : Base principale
- **Redis** (optionnel) : Cache et sessions Socket.IO

## Déploiement

### Environnements
- **Development** : Docker Compose local
- **Production** : 
  - Backend : PM2 ou Docker
  - Frontend : Vercel/Netlify ou serveur statique
  - Database : MySQL cloud (PlanetScale, AWS RDS)

### Variables d'environnement
```env
# Database
DATABASE_URL=mysql://...
REDIS_URL=redis://...

# Auth
JWT_SECRET=...
GOOGLE_CLIENT_ID=...
FACEBOOK_APP_ID=...

# External APIs
DEEZER_APP_ID=...
DEEZER_SECRET=...
```

## Scalabilité

### Performance
- Connection pooling (MySQL)
- Redis pour sessions Socket.IO
- CDN pour assets statiques
- Rate limiting intelligent

### Monitoring
- Logs structurés (Winston)
- Métriques temps réel
- Health checks endpoints

Cette architecture permet une séparation claire des responsabilités, une scalabilité horizontale, et une maintainabilité élevée. Chaque module peut être développé et testé indépendamment.