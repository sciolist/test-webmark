module.exports = {
    "outputPath": "./out",
    "docker": {
        "type": "hostlist",
        "hosts": [
            {
                "URL": `http://localhost:3000`,
                "database": {
                    "PGMAXCONNECTIONS": "99000",
                    "PGUSER": "benchy",
                    "PGPASSWORD": "benchy",
                    "PGDATABASE": "benchy",
                    "PGHOST": "159.89.106.53",
                    "PGPORT": "5432",
                    "PGSSLMODE": "prefer"
                }
            }
        ]
    }
}

/*
// Example: single remote host
//
// The remote host must be configured for remote access.
// Pass "-h tcp://0.0.0.0:2375" when starting the docker service.
//

module.exports = {
    docker: {
        type: "hostlist",
        hosts: [
            {
                "URL": `http://myothermachine:3000`,
                "DOCKER_HOST": `tcp://myothermachine:2375`
            }
        ]
    }
}
*/
