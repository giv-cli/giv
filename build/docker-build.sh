#! /bin/bash
docker build -f build/Dockerfile -t giv:latest . 
docker run --rm -v "$(pwd)":/workspace giv:latest
