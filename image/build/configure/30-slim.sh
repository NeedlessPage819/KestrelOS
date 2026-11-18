# Leave out what nothing in Kestrel uses; every MB is on the live ISO twice (DECISIONS.md D22).
# Each removal was checked: no other package depends on it.
#   plasma-workspace-wallpapers  KDE's default wallpapers (295 MB); Kestrel has its own
#   python3-boto3 and friends    Amazon cloud storage library from the base image (125 MB)
dnf5 -y remove plasma-workspace-wallpapers python3-boto3 python3-botocore python3-s3transfer
