#!/bin/bash

# Remove any existing ZIP file
rm -f ../infrastructure/backend/lambda_functions/lambda_function_backend.zip

# Package the code into a ZIP file
zip ../infrastructure/backend/lambda_functions/lambda_function_backend.zip lambda_function.py