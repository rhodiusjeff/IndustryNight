/**
 * Jest Global Teardown
 *
 * Runs ONCE after all test suites complete. Stops the PostgreSQL
 * container that was started in setup.ts. Also cleans up the temp
 * config file.
 */
import * as fs from 'fs';
import * as path from 'path';

export default async function teardown() {
  const configPath = path.join(__dirname, '.test-db-config.json');

  try {
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

      console.log('\n🛑 Stopping PostgreSQL test container...');
      // Use docker stop via the container ID
      const { execSync } = require('child_process');
      execSync(`docker stop ${config.containerId}`, { stdio: 'ignore' });
      console.log('✅ Container stopped\n');

      fs.unlinkSync(configPath);
    }
  } catch (error) {
    // Container may already be stopped; that's fine
    console.warn('⚠️  Container cleanup warning:', (error as Error).message);
    // Still try to clean up the config file
    if (fs.existsSync(configPath)) {
      fs.unlinkSync(configPath);
    }
  }
}
