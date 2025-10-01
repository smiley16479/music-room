import { Module } from '@nestjs/common';
import { GeocodingService } from './services/geocoding.service';
import { GeocodingController } from './controllers/geocoding.controller';

@Module({
  providers: [GeocodingService],
  controllers: [GeocodingController],
  exports: [GeocodingService],
})
export class CommonModule {}
