#!/usr/bin/env python3
import os
import sys
import uuid

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "saleor.settings")
sys.path.insert(0, "/app")

import django

django.setup()

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage

name = f"verification/{uuid.uuid4().hex}.txt"
payload = b"saleor-railway-storage-check"
stored = default_storage.save(name, ContentFile(payload))
try:
    with default_storage.open(stored, "rb") as handle:
        assert handle.read() == payload
finally:
    default_storage.delete(stored)
print("Saleor object-storage write/read/delete passed.")
