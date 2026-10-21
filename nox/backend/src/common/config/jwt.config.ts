import { ConfigService } from '@nestjs/config';

/** Returns JWT_SECRET from config, failing fast at startup if it is missing. */
export function getJwtSecret(config: ConfigService): string {
  const secret = config.get<string>('JWT_SECRET');
  if (!secret) {
    throw new Error('JWT_SECRET is not set. Define it in the environment or the root .env file.');
  }
  return secret;
}
