#!/usr/bin/env nix-shell
#!nix-shell -i python --pure -p python3Packages.requests -p python3Packages.lxml

import base64
import json
import hashlib
import sys

import requests
from lxml import etree

release = sys.argv[1]

doc = requests.get(f'https://releases.openstack.org/{release}/')
doc = etree.HTML(doc.text)

prev_name = ''

print('''
[tool.poetry]
name = "openstack"
version = "0.0.0"
description = ""
authors = []

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"

[tool.poetry.dev-dependencies]

[tool.poetry.dependencies]
python = "^3.9"''')


for url in doc.xpath('//a[text() = "pgp"]/@href'):
    file = url.split('/')[-1]
    name = '-'.join(file.split('-')[:-1])
    if name == prev_name:
        continue

    if name.startswith('puppet-'):
        continue

    if 'adjutant' in name:
        continue

    if name.startswith('kayobe-'):
        continue

    if name.startswith('ansible-'):
        continue

    prev_name = name

    version = '.'.join(file.split('-')[-1].split('.')[:-3])

    print(f'"{name}" = "{version}"')
