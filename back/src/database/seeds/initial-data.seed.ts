import { DataSource } from 'typeorm';
import { User, VisibilityLevel } from 'src/user/entities/user.entity';
import { Track } from 'src/track/entities/track.entity';
import * as bcrypt from 'bcrypt';

export async function seedInitialData(dataSource: DataSource) {
  const userRepository = dataSource.getRepository(User);
  const trackRepository = dataSource.getRepository(Track);

  // Create test users
  const hashedPassword = await bcrypt.hash('password123', 10);
  
  const testUsers = [
    {
      email: 'alice@example.com',
      password: hashedPassword,
      displayName: 'Alice Johnson',
      emailVerified: true,
      displayNameVisibility: VisibilityLevel.PUBLIC,
      musicPreferences: {
        favoriteGenres: ['Rock', 'Pop', 'Indie'],
        favoriteArtists: ['The Beatles', 'Radiohead', 'Arctic Monkeys'],
      },
    },
    {
      email: 'bob@example.com',
      password: hashedPassword,
      displayName: 'Bob Smith',
      emailVerified: true,
      displayNameVisibility: VisibilityLevel.PUBLIC,
      musicPreferences: {
        favoriteGenres: ['Hip-Hop', 'R&B', 'Jazz'],
        favoriteArtists: ['Kendrick Lamar', 'Frank Ocean', 'Miles Davis'],
      },
    },
    {
      email: 'charlie@example.com',
      password: hashedPassword,
      displayName: 'Charlie Brown',
      emailVerified: true,
      displayNameVisibility: VisibilityLevel.PUBLIC,
      musicPreferences: {
        favoriteGenres: ['Electronic', 'House', 'Techno'],
        favoriteArtists: ['Daft Punk', 'Deadmau5', 'Calvin Harris'],
      },
    },
  ];

  for (const userData of testUsers) {
    const existingUser = await userRepository.findOne({
      where: { email: userData.email },
    });
    
    if (!existingUser) {
      const user = userRepository.create(userData);
      await userRepository.save(user);
      console.log(`Created user: ${userData.email}`);
    }
  }

  // Create some sample tracks (you'll replace these with real Deezer data)
  const sampleTracks = [
    {
      deezerId: '1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: 355,
      genres: ['Rock', 'Classic Rock'],
      releaseDate: new Date('1975-10-31'),
    },
    {
      deezerId: '2',
      title: 'Billie Jean',
      artist: 'Michael Jackson',
      album: 'Thriller',
      duration: 294,
      genres: ['Pop', 'R&B'],
      releaseDate: new Date('1982-11-30'),
    },
    {
      deezerId: '3',
      title: 'Hotel California',
      artist: 'Eagles',
      album: 'Hotel California',
      duration: 391,
      genres: ['Rock', 'Classic Rock'],
      releaseDate: new Date('1976-12-08'),
    },
    {
      deezerId: '4',
      title: 'Smells Like Teen Spirit',
      artist: 'Nirvana',
      album: 'Nevermind',
      duration: 301,
      genres: ['Grunge', 'Alternative Rock'],
      releaseDate: new Date('1991-09-10'),
    },
    {
      deezerId: '5',
      title: 'One More Time',
      artist: 'Daft Punk',
      album: 'Discovery',
      duration: 320,
      genres: ['Electronic', 'House'],
      releaseDate: new Date('2000-11-13'),
    },
  ];

  for (const trackData of sampleTracks) {
    const existingTrack = await trackRepository.findOne({
      where: { deezerId: trackData.deezerId },
    });
    
    if (!existingTrack) {
      const track = trackRepository.create(trackData);
      await trackRepository.save(track);
      console.log(`Created track: ${trackData.title} by ${trackData.artist}`);
    }
  }

  console.log('Initial data seeding completed!');
}