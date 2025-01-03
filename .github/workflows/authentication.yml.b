name: Authentication Workflow

on:
  workflow_call:
    secrets:
      AZURE_CLIENT_ID:
        description: Azure Client Id
        required: true
      AZURE_TENANT_ID:
        description: Azure Tenant Id
        required: true
      AZURE_SUBSCRIPTION_ID:
        description: Azure Subscription Id
        required: true
      AWS_GITHUB_OIDC_ROLE_ARN:
        description: AWS OIDC Role to assume and use as a jump to the execution role
        required: true
      AWS_GITHUB_OIDC_EXECUTION_ROLE_ARN:
        description: AWS Execution role to perform actions in the account
        required: true
    inputs:
      AWS_REGION:
        description: AWS Region - even though a global service - still needs defining
        required: true
        type: string
    outputs:
      AWS_ACCESS_KEY_ID: 
        value: ${{ env.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: 
        value: ${{ env.AWS_SECRET_ACCESS_KEY }}
      AWS_SESSION_TOKEN: 
        value: ${{ env.AWS_SECRET_ACCESS_KEY }}
      AWS_REGION: 
        value: ${{ inputs.AWS_REGION }}

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      # Authenticate with Azure
      #- name: Authenticate with Azure
      #  uses: azure/login@v1
      #  with:
      #    client-id: ${{ secrets.AZURE_CLIENT_ID }}
      #    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      #    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      #- name: Show Subscription
      #  run: |
      #    az account show

      # Configure AWS Credentials for OIDC Role
      - name: Configure AWS Credentials
        id: assume_oidc_role
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ${{ inputs.AWS_REGION }}
          role-to-assume: ${{ secrets.AWS_GITHUB_OIDC_ROLE_ARN }}
          role-duration-seconds: 3600
          role-skip-session-tagging: true
          output-credentials: true

      - name: Check pre Creds
        run: |
         echo ${{ env.AWS_ACCESS_KEY_ID }} | base64

      # Assume AWS Execution Role
      - name: Assume Execution Role
        id: assume_execution_role
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-session-token: ${{ env.AWS_SESSION_TOKEN }}
          role-to-assume: ${{ secrets.AWS_GITHUB_OIDC_EXECUTION_ROLE_ARN }}
          aws-region: ${{ inputs.AWS_REGION }}
          role-duration-seconds: 3000
          role-skip-session-tagging: true
          output-credentials: true

      # Test AWS Role Access
      - name: Test Role Access
        run: aws sts get-caller-identity

      - name: Test AWS Identity
        env:
          AWS_ACCESS_KEY_ID: ${{ needs.authentication.outputs.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ needs.authentication.outputs.AWS_SECRET_ACCESS_KEY }}
          AWS_SESSION_TOKEN: ${{ needs.authentication.outputs.AWS_SESSION_TOKEN }}
          AWS_REGION: ${{ needs.authentication.outputs.AWS_REGION }}
        run: aws sts get-caller-identity 
