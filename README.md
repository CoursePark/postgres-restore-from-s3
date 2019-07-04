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

A date can be specified with the `DUMP_OBJECT_DATE` environment variable to get an image at that date or if not found, the most recent before it.

```
	-e DUMP_OBJECT_DATE=_____ \ # YYYY-MM-DDThh:mm , times in UTC
```

To avoid redownloading the same database dump when restoring multiple times, use a docker volume mapped the container's /cache directory. Mapping to `$(pwd)/dump` will create a `dump` directory in the current directory. Downloaded dump files will go in that and will be named according to the _file name_ of the S3 object as opposed to the _path and file name_. Because new .dump files may be continuously avaialble for download, it is recommended to use `DUMP_OBJECT_DATE` with the `DUMP_OBJECT_PREFIX` environment variable to specify a particular dump.

```
	-v $(pwd)/dump:/cache
```

If a specific dump is wanted from S3, `DUMP_OBJECT` can be used instead of `DUMP_OBJECT_PREFIX` and `DUMP_OBJECT_DATE`, to specify the full object path on S3 of a desired dump.

```
	-e DUMP_OBJECT=_____ \ # path/object
```

To limit the restore to a particular schema, the `SCHEMA` environment variable can be passed. _Note_ that the entire database will be dropped in the restore process. This will not preserve other schemas.

```
    -e SCHEMA=_____ \ # public or other
```

To execute arbitrary psql / SQL commands before or after the internal _pg_restore_ command, the `PRE_RESTORE_PSQL` and `POST_RESTORE_PSQL` environment variables can be passed. `PRE_RESTORE_PSQL` can is particularly useful for `CREATE EXTENSION ___;` when also specifying a `SCHEMA` as _pg_restore_ doesn't execute such database level commands when targeted to a particular schema or table.

```
    -e PRE_RESTORE_PSQL="____" \ # "CREATE EXTENSION postgis; CREATE EXTENSION pg_trgm;"
```

### AWS multi-factor authentication

If an AWS MFA code isn't passed to `action.sh` as an argument it will be requested.

Authentication via AWS MFA can be enabled by setting the following environment variable.

```
-e AWS_MFA_DEVICE_ARN=<AWS_MFA_DEVICE_ARN>
```

In order for the temporary AWS MFA credentials to persist until they expire a volume must be mounted.

```
-v /tmp/.aws/:/root/.aws/
```

***Note**: the usual cron tricks apply to the hour and minute env values. For instance setting `CRON_HOUR` to `*/4` and `CRON_MINUTE` to `0`, will trigger once every 4 hours.*

Creating database dumps can be accomplished with the `bluedrop360/postgres-dump-to-s3` repo.
