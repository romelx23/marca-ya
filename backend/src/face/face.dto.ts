import { ArrayMaxSize, ArrayMinSize, IsArray, IsString, Matches } from 'class-validator';

export class ConsentDto {
  @IsString() version!: string;
}

export class EnrollDto {
  /** 3 a 5 vectores de EMBEDDING_DIM números, generados en el teléfono. */
  @IsArray() @ArrayMinSize(3) @ArrayMaxSize(5) embeddings!: number[][];
  /** PIN de respaldo de 4 a 6 dígitos. */
  @IsString() @Matches(/^\d{4,6}$/) pin!: string;
}
