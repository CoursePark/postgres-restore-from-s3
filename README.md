# postgres-restore-from-s3

Cron based download from s3 and database restore.

## Usage

Typically this image is instantiated as a container among many others and would have the responsibility of getting downloading a dump file from s3 and restoring a database at a particular time of day.

For instance: a QC environment might reset its data to a production backup nightly.

With a `docker-compose` set up, this might look like the following:

`docker-compose.qc.yml` defines a service:

```
  postgres-restore-from-s3:
    image: bluedrop360/postgres-restore-from-s3
    environment:
        AWS_ACCESS_KEY_ID: ...
        AWS_SECRET_ACCESS_KEY: ...
        AWS_BUCKET: ...
        DUMP_OBJECT_PREFIX: ...
        AWS_REGION: s3
        CRON_HOUR: 2
        CRON_MINUTE: 0
        DATABASE_URL: postgres://...
    restart: always
```

***Note**: the usual cron tricks apply to the hour and minute env values. For instance setting `CRON_HOUR` to `*/4` and `CRON_MINUTE` to `0`, will trigger once every 4 hours.*

Creating database dumps can be accomplished with the `bluedrop360/postgres-dump-to-s3` repo.
