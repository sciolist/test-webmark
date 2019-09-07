import pg from 'pg-promise';
import fs from 'fs';
import path from 'path';

const dbsetup = fs.readFileSync(path.resolve(__dirname, '../database/database.sql'));

export async function setupDatabase() {
    if (!process.env.PGHOST) return;
    console.log('initializing database...');
    const pgp = pg()({});
    const conn = await pgp.connect();
    await conn.query(dbsetup.toString());
}
