# Snapshots

The script `snapshots.sh` is executed in the controller. It gets a list of
UUIDS of each instance in the tenant and searches for attached volumes to create the snapshots.

When the `TEST` var is set to `y`, the script uses the file `test_instance_id.txt` which contains the UUID(s) of the instance(s) to create the snapshots.

The volumes are stored as CEPH block devices (RBD).

