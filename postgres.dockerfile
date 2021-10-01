FROM postgres:14
COPY postgres.sql /docker-entrypoint-initdb.d/postgres.sql
CMD ["postgres", "-N", "80000"]