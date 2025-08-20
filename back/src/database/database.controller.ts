import { Controller, Get, Logger } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Database')
@Controller('database')
export class DatabaseController {
    private readonly logger = new Logger(DatabaseController.name);
  
  constructor(private readonly databaseService: DatabaseService) {
  }
    @Get('seed')
    @ApiOperation({
      summary: 'Seed the database',
      description: 'Initializes the database with sample data for testing and development',
    })
    findOne() {
      this.logger.log('Seeding the database...');
      return this.databaseService.initializeDatabase();
    }
}
