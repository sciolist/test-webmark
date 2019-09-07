import pg from 'pg-promise';
import fs from 'fs';
import path from 'path';
import { IDockerhost } from '../docker/pool';

const dbsetup = fs.readFileSync(path.resolve(__dirname, '../database/database.sql'));

export async function setupDatabase(host: IDockerhost) {
    if (!process.env.database) return;
    console.log('initializing database...');
    const pgp = pg()({});
    const conn = await pgp.connect();
    await conn.query(dbsetup.toString());
}
