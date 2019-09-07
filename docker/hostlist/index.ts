import GenericPool from 'generic-pool';
import { IDockerhost } from '../pool';

export async function startup(cfg) {
    const hosts = [ ...cfg.hosts ];
    const opts: GenericPool.Options = { min: hosts.length, max: hosts.length };
    return GenericPool.createPool<IDockerhost>({
        async create() { return hosts.pop(); },
        async destroy(client) {}
    }, opts);
}

export async function shutdown(cfg) {

}
