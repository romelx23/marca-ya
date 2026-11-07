import { IsIn, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsString() @MinLength(20) @MaxLength(4096) token!: string;
  @IsIn(['android', 'ios', 'web']) platform!: 'android' | 'ios' | 'web';
}

export class SendNotificationDto {
  @IsUUID() employeeId!: string;
  @IsString() @MinLength(1) @MaxLength(80) title!: string;
  @IsString() @MinLength(1) @MaxLength(240) body!: string;
}
