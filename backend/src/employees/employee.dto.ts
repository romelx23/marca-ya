import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export const ROLES = ['employee', 'manager', 'hr', 'admin'] as const;

export class CreateEmployeeDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(8) password!: string;
  @IsString() @MinLength(2) fullName!: string;
  @IsOptional() @IsString() documentId?: string;
  @IsOptional() @IsIn(ROLES) role?: (typeof ROLES)[number];
}

export class UpdateEmployeeDto {
  @IsOptional() @IsString() @MinLength(2) fullName?: string;
  @IsOptional() @IsString() documentId?: string;
  @IsOptional() @IsIn(ROLES) role?: (typeof ROLES)[number];
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsString() @MinLength(8) password?: string;
}
