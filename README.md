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

In addition it can be used manually like:

```
docker run --rm \
	-e AWS_ACCESS_KEY_ID=_____ \ # like AKBCWALBJRESOB5PLDPA
	-e AWS_BUCKET=_____ \
	-e AWS_REGION=_____ \ # ca-central-1
	-e AWS_SECRET_ACCESS_KEY=_____ \ # 38laOPbedznMueTrMDHapWb4KKlwPPme7aGuHKWE
	-e DATABASE_URL=_____ \ # postgres://user:password@host:5432/database
	-e DUMP_OBJECT_PREFIX=_____ \ # path/subpath/
	bluedrop360/postgres-restore-from-s3 ./action.sh
```

Optionally a date can be specified with the `DUMP_OBJECT_DATE` environment variable to get an image at that date or if not found, the most recent before it.

```
	-e DUMP_OBJECT_DATE=_____ \ # YYYY-MM-DDThh:mm , times in UTC
```

If a specific dump is wanted from S3, `DUMP_OBJECT` can be used instead of `DUMP_OBJECT_PREFIX` and `DUMP_OBJECT_DATE`, to specify the full object path on S3 of a desired dump.

```
	-e DUMP_OBJECT=_____ \ # path/object
```

***Note**: the usual cron tricks apply to the hour and minute env values. For instance setting `CRON_HOUR` to `*/4` and `CRON_MINUTE` to `0`, will trigger once every 4 hours.*

Creating database dumps can be accomplished with the `bluedrop360/postgres-dump-to-s3` repo.
