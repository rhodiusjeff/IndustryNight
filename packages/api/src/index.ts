import app from './app';
import { config } from './config/env';

const PORT = config.port;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${config.nodeEnv}`);
  if (process.env.ENABLE_MAGIC_TEST_PREFIX === 'true') {
    console.warn('[SECURITY] ENABLE_MAGIC_TEST_PREFIX=true — magic test phone prefix is active. Ensure this is intentional for this environment.');
  }
});

export default app;
