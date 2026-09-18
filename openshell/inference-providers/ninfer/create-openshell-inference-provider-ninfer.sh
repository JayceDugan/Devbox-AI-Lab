#!/bin/bash

openshell provider create \
    --name ninfer \
    --type openai \
    --credential OPENAI_API_KEY=empty \
    --config OPENAI_BASE_URL=http://host.openshell.internal:8088/v1
