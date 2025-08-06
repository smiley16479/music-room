import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { DeviceController } from './device.controller';
import { DeviceService } from './device.service';
import { DeviceGateway } from './device.gateway';

import { Device } from 'src/device/entities/device.entity';
import { User } from 'src/user/entities/user.entity';

import { UserModule } from '../user/user.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Device, User]),
    UserModule,
  ],
  controllers: [DeviceController],
  providers: [DeviceService, DeviceGateway, JwtService],
  exports: [DeviceService],
})
export class DeviceModule {}