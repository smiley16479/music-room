import { AppDataSource } from '../data-source';
import { seedInitialData } from './initial-data.seed';

async function runSeed() {
  try {
    await AppDataSource.initialize();
    console.log('Database connection established');
    
    await seedInitialData(AppDataSource);
    
    await AppDataSource.destroy();
    console.log('Seeding completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error during seeding:', error);
    process.exit(1);
  }
}

runSeed();