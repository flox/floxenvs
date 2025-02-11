#!/usr/bin/env bash

set -eo pipefail

jupyter nbconvert --to notebook --execute ./barcode_demo.ipynb
jupyter nbconvert --to notebook --execute ./tricontour_demo.ipynb

