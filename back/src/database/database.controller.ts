import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Database')
@Controller('database')
export class DatabaseController {
  constructor(private readonly databaseService: DatabaseService) {
  }
    @Get('seed')
    @ApiOperation({
      summary: 'Seed the database',
      description: 'Initializes the database with sample data for testing and development',
    })
    findOne() {
      return this.databaseService.initializeDatabase();
    }
}
