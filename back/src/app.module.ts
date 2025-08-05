import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const url = configService.get<string>('DATABASE_URL');
        console.log('DB URL used by TypeORM:', url);
        return {
          type: 'mysql',
          url,
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          cache: false,
          synchronize: true,
        };
      }
    }),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
