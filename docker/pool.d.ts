
export interface IDockerhost {
    URL: string;
    database?: { [key: string]: any; };
    [key: string]: any;
}