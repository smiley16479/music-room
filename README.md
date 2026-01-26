# 🎵 Music Room - Documentation Centralisée

Bienvenue dans **Music Room**, une plateforme événementielle dédiée à la musique!

> ⚡ **Première visite?** Commencez par [QUICK_START.md](./QUICK_START.md) (5 min)

---

## 📚 Documentation Complète

### 🚀 Pour Démarrer
- **[QUICK_START.md](./QUICK_START.md)** - Setup rapide en 5 minutes
- **[SWAGGER_DOCS.md](./SWAGGER_DOCS.md)** - Comment utiliser Swagger pour tester les APIs

### 📖 Architecture & Référence
- **[REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md)** - Architecture Event-Centric expliquée
- **[API_ENDPOINTS.md](./API_ENDPOINTS.md)** - Documentation complète de tous les endpoints
- **[FLUTTER_MIGRATION_GUIDE.md](./FLUTTER_MIGRATION_GUIDE.md)** - Guide d'intégration Flutter

### 📋 Planning & État
- **[TODO.md](./TODO.md)** - État du projet, priorités, et roadmap

### 🌐 Accès Directs
- **[Documentation Swagger Live](http://localhost:3000/api/docs)** - Une fois le serveur lancé
- **[API Endpoint](http://localhost:3000/api)** - Base URL de l'API

---

## 🎯 Par Où Commencer?

### 👨‍💼 Manager / Product Owner
1. Lire: [QUICK_START.md](./QUICK_START.md) (5 min)
2. Consulter: [TODO.md](./TODO.md) (10 min)
3. Explorer: [SWAGGER_DOCS.md](./SWAGGER_DOCS.md) (10 min)

### 🔧 Développeur Backend
1. Lire: [QUICK_START.md](./QUICK_START.md) (5 min)
2. Comprendre: [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) (20 min)
3. Consulter: [API_ENDPOINTS.md](./API_ENDPOINTS.md) (30 min)
4. Démarrer: Lancer serveur et [http://localhost:3000/api/docs](http://localhost:3000/api/docs)

### 📱 Développeur Flutter
1. Lire: [QUICK_START.md](./QUICK_START.md) (5 min)
2. Étudier: [FLUTTER_MIGRATION_GUIDE.md](./FLUTTER_MIGRATION_GUIDE.md) (20 min)
3. Consulter: [API_ENDPOINTS.md](./API_ENDPOINTS.md) (30 min)
4. Coder: Intégrer avec le backend

### 🏗️ Architecte / Tech Lead
1. Lire: [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) (25 min)
2. Approfondir: [API_ENDPOINTS.md](./API_ENDPOINTS.md) (40 min)
3. Planifier: [TODO.md](./TODO.md) (15 min)
4. Reviewer: [FLUTTER_MIGRATION_GUIDE.md](./FLUTTER_MIGRATION_GUIDE.md) (20 min)

---

## 🏗️ Vue d'Ensemble Technique

```
┌──────────────────────────────────────────────────────────────┐
│                     🎵 Music Room                             │
└──────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
           ┌────▼────┐   ┌────▼────┐  ┌───▼────┐
           │ Flutter  │   │ NestJS  │  │  Vue/  │
           │   App    │   │ Backend │  │  Web   │
           └────┬────┘   └────┬────┘  └───┬────┘
                │             │            │
                └─────────────┼────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   REST API v1.0   │
                    │  @/api/docs       │
                    └─────────┬─────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
           ┌────▼────┐   ┌────▼────┐  ┌───▼─────┐
           │PostgreSQL│   │  Redis  │  │Socket.io│
           │ Database │   │  Cache  │  │WebSocket│
           └──────────┘   └─────────┘  └────┬────┘
                                             │
                                    ┌────────▼────────┐
                                    │ Real-time Events│
                                    │  Push Updates   │
                                    └─────────────────┘
```

---

## 🎯 Caractéristiques Principales

### 🎵 Events
- ✅ Créer, modifier, supprimer événements
- ✅ Types: LISTENING_SESSION, PARTY, COLLABORATIVE, LIVE_SESSION
- ✅ Visibilité: PUBLIC, PRIVATE
- ✅ Location-based filtering
- ✅ Édition par admin

### 🎧 Playlists
- ✅ Gestion des pistes (CRUD)
- ✅ Réorganisation (drag & drop)
- ✅ Collaboration avec d'autres utilisateurs
- ✅ Partage et invitations

### 🗳️ Voting System
- ✅ Upvote/Downvote en temps réel
- ✅ Skip tracks
- ✅ Vote results tracking
- ✅ WebSocket live updates

### 🔐 Authentication
- ✅ Email/Password avec JWT
- ✅ Google OAuth
- ✅ Facebook OAuth
- ✅ Token refresh
- ✅ Password reset

### 🎸 Music Search
- ✅ Spotify search
- ✅ Deezer search
- ✅ Track caching avec Redis
- ✅ Metadata enrichment

### 👥 Social
- ✅ User profiles
- ✅ Invitations
- ✅ Participant management
- ✅ Admin roles

---

## 🚀 Démarrer Rapidement

### 1. Lancer le serveur
```bash
cd back
npm install
npm run start:dev
```

### 2. Accéder à Swagger
```
http://localhost:3000/api/docs
```

### 3. Tester une API
Cliquez "Authorize", entrez un token JWT, puis "Try it out" sur un endpoint

### 4. Lancer Flutter (optionnel)
```bash
cd flutter_app_
flutter pub get
flutter run
```

**Temps total**: ~5 minutes ⚡

---

## 📚 Document Map

```
README.md (ce fichier)
├── QUICK_START.md (Setup 5 min)
│   ├── SWAGGER_DOCS.md (Tester les APIs)
│   └── API_ENDPOINTS.md (Référence complète)
│
├── REFACTORING_SUMMARY.md (Architecture)
│   └── FLUTTER_MIGRATION_GUIDE.md (Frontend)
│
└── TODO.md (Planning & État)
```

---

## 🔗 Liens Rapides

| Ressource | URL |
|-----------|-----|
| 📖 **Swagger** | http://localhost:3000/api/docs |
| 🔌 **API** | http://localhost:3000/api |
| 📱 **WebSocket** | http://localhost:3000/events |

| Code | Localisation |
|------|-------------|
| Backend | `/back/src` |
| Frontend Flutter | `/flutter_app_/lib` |
| Database | `/db/migrations` |
| Docker | `docker-compose.yml` |

---

## 💡 Architecture Highlights

### Event-Centric Design
- **Pattern**: Single Table Inheritance
- **Concept**: Playlist = Event avec type='LISTENING_SESSION'
- **Avantage**: Code simplifié, moins de duplication
- **Plus**: Voir [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md)

### Tech Stack
```
Backend:  NestJS 11 + TypeORM + PostgreSQL + Redis + Socket.io
Frontend: Flutter (Dart) + Provider + HTTP + WebSocket
DevOps:   Docker, Docker Compose, PostgreSQL, Redis
```

### APIs Documentation
- **Format**: OpenAPI 3.0 (Swagger)
- **Auto-generated**: Oui, via NestJS decorators
- **Live**: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)
- **Reference**: [API_ENDPOINTS.md](./API_ENDPOINTS.md)

---

## 📊 État du Projet

| Aspect | Statut | Notes |
|--------|--------|-------|
| Backend | ✅ Core | CRUD, Auth, Voting, Real-time |
| Frontend | ✅ Core | Flutter app fonctionnelle |
| Database | ✅ Prête | PostgreSQL + migrations |
| Documentation | ✅ Complète | Swagger + Markdown guides |
| Tests | ❌ À faire | Backend tests manquants |
| Deployment | ⏳ Planifié | Docker ready |

**Pour plus**: Voir [TODO.md](./TODO.md)

---

## 🆘 Aide & Dépannage

### "Le serveur ne démarre pas"
→ Vérifiez [QUICK_START.md](./QUICK_START.md) section "Vérifier le statut"

### "Erreur d'authentification"
→ Consultez [SWAGGER_DOCS.md](./SWAGGER_DOCS.md) section "Authentification"

### "API error X"
→ Voir [SWAGGER_DOCS.md](./SWAGGER_DOCS.md) section "Dépannage"

### "Comment ajouter une feature?"
→ Lire [TODO.md](./TODO.md) pour les priorités

### "Comment intégrer Flutter?"
→ Suivre [FLUTTER_MIGRATION_GUIDE.md](./FLUTTER_MIGRATION_GUIDE.md)

---

## 🎯 Prochaines Étapes

1. **Immédiat**: Lire [QUICK_START.md](./QUICK_START.md) (5 min)
2. **Aujourd'hui**: Lancer serveur et tester Swagger (10 min)
3. **Cette semaine**: Comprendre architecture [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) (30 min)
4. **Ce mois**: Commencer développement selon [TODO.md](./TODO.md)

---

## 📞 Ressources

- 📖 **Documentation**: Fichiers `.md` dans ce dossier
- 🔗 **Swagger Live**: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)
- 💻 **Code**: `/back/src`, `/flutter_app_/lib`
- 💾 **Database**: `/db/migrations`

---

**Prêt à explorer?** 👉 [Commencer par QUICK_START.md](./QUICK_START.md)

---

*Dernière mise à jour: Janvier 2026*  
*Version: 1.0.0*  
*Mainteneur: GitHub Copilot*
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
- Informations sur les albums et artistes

### YouTube API
- Recherche de vidéos musicales
- Lecture complète des tracks (vs 30s previews)
- Intégration du lecteur YouTube IFrame API

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
YOUTUBE_API_KEY=...
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