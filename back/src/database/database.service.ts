import { Injectable } from '@nestjs/common';
import { AppDataSource } from './data-source';
import { seedInitialData } from './seeds/initial-data.seed';


@Injectable()
export class DatabaseService {

  async initializeDatabase() {
    try {
        // Initialize connection
        await AppDataSource.initialize();
        console.log('✅ Database connection established');

        // Run synchronization in development
        if (process.env.NODE_ENV === 'dev') {
          await AppDataSource.synchronize();
          console.log('✅ Database schema synchronized');
        }

        // Seed initial data
        await seedInitialData(AppDataSource);
        console.log('✅ Initial data seeded');

        return AppDataSource;
    } catch (error) {
        console.error('❌ Database initialization failed:', error);
        throw error;
    }
  }
}
