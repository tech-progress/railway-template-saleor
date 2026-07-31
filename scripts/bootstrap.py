#!/usr/bin/env python3
import os
import sys

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "saleor.settings")
sys.path.insert(0, "/app")

import django

django.setup()

from django.core.management import call_command
from saleor.account.models import User

call_command("migrate", interactive=False)

email = os.environ["ADMIN_EMAIL"].strip().lower()
password = os.environ["ADMIN_PASSWORD"]
user, created = User.objects.get_or_create(
    email=email,
    defaults={"is_active": True, "is_staff": True, "is_superuser": True},
)
if created:
    user.set_password(password)
    user.save(update_fields=["password"])
    print(f"Created Saleor administrator {email}.")
else:
    changed = False
    for field in ("is_active", "is_staff", "is_superuser"):
        if not getattr(user, field):
            setattr(user, field, True)
            changed = True
    if changed:
        user.save(update_fields=["is_active", "is_staff", "is_superuser"])
    print(f"Saleor administrator {email} already exists; password was preserved.")

if os.environ.get("AWS_AUTO_CREATE_BUCKET", "false").lower() == "true":
    import time

    import boto3
    from botocore.exceptions import ClientError

    bucket = os.environ["AWS_MEDIA_BUCKET_NAME"]
    client = boto3.client(
        "s3",
        endpoint_url=os.environ.get("AWS_S3_ENDPOINT_URL"),
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
        region_name=os.environ.get("AWS_S3_REGION_NAME"),
    )
    for attempt in range(30):
        try:
            client.head_bucket(Bucket=bucket)
            break
        except ClientError as error:
            status = error.response.get("ResponseMetadata", {}).get("HTTPStatusCode")
            if status == 404:
                client.create_bucket(Bucket=bucket)
                print(f"Created local S3 bucket {bucket}.")
                break
            if attempt == 29:
                raise
        except Exception:
            if attempt == 29:
                raise
        time.sleep(2)
