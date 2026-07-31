#!/usr/bin/env python3
"""Load Saleor's shared JWT key from S3, creating it once from the API service."""

from __future__ import annotations

import os
import sys
import time

import boto3
from botocore.exceptions import ClientError, EndpointConnectionError
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

KEY_OBJECT = ".saleor/jwt-private-key.pem"
WAIT_SECONDS = 180


def client():
    return boto3.client(
        "s3",
        endpoint_url=os.environ["AWS_S3_ENDPOINT_URL"],
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
        region_name=os.environ.get("AWS_S3_REGION_NAME") or "us-east-1",
    )


def read_key(s3, bucket: str) -> bytes | None:
    try:
        return s3.get_object(Bucket=bucket, Key=KEY_OBJECT)["Body"].read()
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")
        if code in {"NoSuchKey", "NoSuchBucket", "404"}:
            return None
        raise


def generate_key() -> bytes:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )


def create_bucket_if_requested(s3, bucket: str) -> None:
    if os.environ.get("AWS_AUTO_CREATE_BUCKET", "false").lower() != "true":
        return
    try:
        s3.head_bucket(Bucket=bucket)
    except ClientError:
        s3.create_bucket(Bucket=bucket)


def load(mode: str) -> bytes:
    bucket = os.environ["AWS_MEDIA_PRIVATE_BUCKET_NAME"]
    deadline = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < deadline:
        try:
            s3 = client()
            create_bucket_if_requested(s3, bucket)
            existing = read_key(s3, bucket)
            if existing:
                return existing
            if mode == "create":
                candidate = generate_key()
                try:
                    s3.put_object(
                        Bucket=bucket,
                        Key=KEY_OBJECT,
                        Body=candidate,
                        ContentType="application/x-pem-file",
                        IfNoneMatch="*",
                    )
                    return candidate
                except ClientError as error:
                    if error.response.get("ResponseMetadata", {}).get("HTTPStatusCode") != 412:
                        raise
                    existing = read_key(s3, bucket)
                    if existing:
                        return existing
        except (ClientError, EndpointConnectionError) as error:
            print(f"Waiting for shared JWT key storage: {error}", file=sys.stderr)
        time.sleep(2)
    raise RuntimeError("Timed out waiting for Saleor's shared JWT private key")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) == 2 else ""
    if mode not in {"create", "wait"}:
        raise SystemExit("usage: load-jwt-key.py create|wait")
    pem = load(mode)
    serialization.load_pem_private_key(pem, password=None)
    sys.stdout.write(pem.decode("ascii"))


if __name__ == "__main__":
    main()
